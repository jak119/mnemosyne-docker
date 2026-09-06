# mnemosyne-docker

A Docker deployment of the [Mnemosyne](https://github.com/mnemosyne-oss/mnemosyne) memory system, supporting both the **MCP server** (port 8080) and the **Sync server** (port 8765) with persistent SQLite storage and local embeddings.

## Requirements

- Docker Engine 24 or newer
- Docker Compose v2
- OpenSSL or another secure token generator

## Quick start

### 1. Configure environment

```sh
cp .env.example .env
```

Generate secure tokens for your services:

```sh
openssl rand -hex 32
```

Configure `.env` according to the mode you want to run:

- **MCP server only (default)**: Set `MNEMOSYNE_MCP_TOKEN` and `COMPOSE_PROFILES=mcp`
- **Sync server only (VPS / remote)**: Set `MNEMOSYNE_SYNC_API_KEY` and `COMPOSE_PROFILES=sync`
- **Both services (MCP + Sync)**: Set both tokens and `COMPOSE_PROFILES=all`

### 2. Start the service(s)

```sh
docker compose up -d
docker compose ps
```

Compose pulls `ghcr.io/jak119/mnemosyne-docker:latest` by default.

---

## Operating Modes

### Mode 1: MCP Server (Default)

The MCP SSE endpoint is served at `http://<server-address>:8080/sse`. Clients authenticate via bearer token:

```text
Authorization: Bearer <MNEMOSYNE_MCP_TOKEN>
```

Start explicitly:
```sh
docker compose --profile mcp up -d
```

### Mode 2: Sync Server

The Sync server enables bidirectional delta sync between Mnemosyne instances (e.g. desktop to VPS). The endpoint is served at `http://<server-address>:8765` (`POST /sync/pull` and `POST /sync/push`).

Start explicitly:
```sh
docker compose --profile sync up -d
```

#### Syncing from a client machine

1. Generate an encryption key (optional but recommended for client-side encryption):
   ```sh
   docker compose exec mnemosyne-sync mnemosyne sync-generate-key > mnemosyne-sync-encryption.key
   ```

2. Initialize a dedicated sync database on the client:
   ```sh
   MNEMOSYNE_SYNC_DB="$HOME/.mnemosyne/shared-surface.db"
   mkdir -p "$(dirname "$MNEMOSYNE_SYNC_DB")"
   chmod 700 "$(dirname "$MNEMOSYNE_SYNC_DB")"
   mnemosyne sync-init --db-path "$MNEMOSYNE_SYNC_DB"
   ```

3. Synchronize memories:
   ```sh
   # Bidirectional sync with API key
   mnemosyne sync --db-path "$MNEMOSYNE_SYNC_DB" \
     --remote https://memory.example.com \
     --api-key "your-sync-api-key"

   # With client-side encryption (payloads encrypted before leaving client)
   MNEMOSYNE_SYNC_KEY="$(cat mnemosyne-sync-encryption.key)" \
     mnemosyne sync --db-path "$MNEMOSYNE_SYNC_DB" \
       --remote https://memory.example.com \
       --api-key "your-sync-api-key" \
       --encrypt
   ```

### Mode 3: Dual Mode (MCP + Sync Server)

Run both the MCP server and the Sync server side-by-side. Both services share the same persistent SQLite database via SQLite WAL mode:

```sh
docker compose --profile all up -d
```

---

## Published image

Successful builds from `main` are published to GitHub Container Registry with `latest` and the Mnemosyne version pinned in `requirements.txt`:

```sh
docker pull ghcr.io/jak119/mnemosyne-docker:latest
docker pull ghcr.io/jak119/mnemosyne-docker:3.15.1
```

After the first publish, set the `mnemosyne-docker` package visibility to **Public** in its GitHub Package settings so hosts without GitHub credentials can pull it.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `COMPOSE_PROFILES` | `mcp` | Active Compose profiles: `mcp` (MCP only), `sync` (Sync only), or `all` (both) |
| `MNEMOSYNE_MCP_TOKEN` | Required for MCP | Bearer token required by Mnemosyne for non-loopback MCP binds |
| `MNEMOSYNE_HOST` | `0.0.0.0` | Host bind address for MCP server |
| `MNEMOSYNE_PORT` | `8080` | Port published for MCP server |
| `MNEMOSYNE_LLM_ENABLED` | `false` | Enables optional LLM-based consolidation when model/backend is available |
| `MNEMOSYNE_SYNC_API_KEY` | Required for Sync | Secret API key for Sync server authentication |
| `MNEMOSYNE_SYNC_HOST` | `0.0.0.0` | Host bind address for Sync server |
| `MNEMOSYNE_SYNC_PORT` | `8765` | Port published for Sync server |
| `MNEMOSYNE_IMAGE_TAG` | `latest` | Published image tag; pin a version for repeatable deployments |

Mnemosyne stores its database at `/data/mnemosyne.db`. The Compose-managed `mnemosyne-data` volume persists the database across container recreations.

## Operations

View logs:

```sh
# All active services
docker compose logs -f

# MCP service only
docker compose logs -f mnemosyne

# Sync service only
docker compose logs -f mnemosyne-sync
```

Stop or restart services:

```sh
docker compose stop
docker compose restart
```

Remove containers without deleting stored data:

```sh
docker compose down
```

Do not pass `--volumes` unless the stored memories should be permanently deleted.

## Backup and restore

Export memories while the service is running:

```sh
docker compose exec mnemosyne mnemosyne export /data/mnemosyne-export.json
docker compose cp mnemosyne:/data/mnemosyne-export.json ./mnemosyne-export.json
```

Restore an export:

```sh
docker compose cp ./mnemosyne-export.json mnemosyne:/data/mnemosyne-export.json
docker compose exec mnemosyne mnemosyne import /data/mnemosyne-export.json
```

Verify database integrity:

```sh
docker compose exec mnemosyne mnemosyne verify /data/mnemosyne.db --quick
```

Keep exports protected because they contain memory content in plaintext.

## Upgrading

The Mnemosyne package is pinned in `requirements.txt`. Before changing the version, create an export, review the upstream release notes, update `MNEMOSYNE_IMAGE_TAG` to the matching published tag, then pull the new image:

```sh
docker compose pull
docker compose up -d
```

Confirm the service becomes healthy before removing a backup.

## Troubleshooting

### Compose reports that tokens are missing

Ensure `.env` exists with `MNEMOSYNE_MCP_TOKEN` set for the MCP server or `MNEMOSYNE_SYNC_API_KEY` set for the Sync server.

### The container repeatedly restarts

Check logs for the failing service:

```sh
docker compose logs mnemosyne
docker compose logs mnemosyne-sync
```

Non-loopback binds are rejected by Mnemosyne when required authentication tokens are missing.

### Health check failures

The image checks active ports (`:8080` for MCP, `:8765` for Sync). Initial startup and embedding model initialization can take longer on resource-constrained hosts.

### Permission errors with a bind mount

The image runs as UID and GID `10001`. If the named volume is replaced with a host bind mount, make the host directory writable by that identity (`chown -R 10001:10001 <path>`).

## Security

- Both services require bearer/API-key authentication.
- Containers run as an unprivileged user (`10001:10001`), drop all Linux capabilities (`cap_drop: ALL`), and enable `no-new-privileges: true`.
- Always protect endpoints behind a TLS reverse proxy (e.g. Caddy, Nginx) before exposing them to untrusted networks or the public Internet.
- When using Sync across untrusted hosts, enable client-side encryption (`--encrypt`).

Mnemosyne is distributed under the MIT License. See the [upstream project](https://github.com/mnemosyne-oss/mnemosyne) for its source and license.
