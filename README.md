# mnemosyne-docker

A Docker deployment of the [Mnemosyne](https://github.com/mnemosyne-oss/mnemosyne) MCP memory server with persistent SQLite storage and local embeddings.

## Requirements

- Docker Engine 24 or newer
- Docker Compose v2
- OpenSSL or another secure token generator

## Quick start

```sh
cp .env.example .env
openssl rand -hex 32
```

Set the generated value as `MNEMOSYNE_MCP_TOKEN` in `.env`, then start the server:

```sh
docker compose up -d
docker compose ps
```

Compose pulls `ghcr.io/jak119/mnemosyne-docker:latest` by default and publishes the MCP SSE endpoint at `http://<server-address>:8080/sse`. Clients must send the token in every request:

```text
Authorization: Bearer <MNEMOSYNE_MCP_TOKEN>
```

> [!WARNING]
> The default `MNEMOSYNE_HOST=0.0.0.0` exposes an authenticated memory service on every network interface. Use a long random `MNEMOSYNE_MCP_TOKEN`, protect the host with a firewall, and use a TLS reverse proxy before exposing the endpoint to an untrusted network or the Internet. Set `MNEMOSYNE_HOST=127.0.0.1` when only local clients need access.

Set `MNEMOSYNE_PORT` to change the host port, `MNEMOSYNE_HOST` to control the bind address, and `MNEMOSYNE_IMAGE_TAG` to select a published version.

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
| `MNEMOSYNE_MCP_TOKEN` | Required | Bearer token required by Mnemosyne for a non-loopback container bind |
| `MNEMOSYNE_IMAGE_TAG` | `latest` | Published image tag; pin a version for repeatable deployments |
| `MNEMOSYNE_HOST` | `0.0.0.0` | Host bind address; use `127.0.0.1` for local-only access |
| `MNEMOSYNE_PORT` | `8080` | Port published on `MNEMOSYNE_HOST` |
| `MNEMOSYNE_LLM_ENABLED` | `false` | Enables optional LLM-based consolidation when its dependencies and model are available |

Mnemosyne stores its database at `/data/mnemosyne.db`. The Compose-managed `mnemosyne-data` volume persists the database when containers are replaced.

Local embeddings are included in the image. The first semantic operation can take longer while the embedding model is initialized or downloaded.

## Operations

View logs:

```sh
docker compose logs -f mnemosyne
```

Stop or restart the service:

```sh
docker compose stop
docker compose restart
```

Remove the container without deleting its data:

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

### Compose reports that `MNEMOSYNE_MCP_TOKEN` must be set

Copy `.env.example` to `.env` and set a non-empty, randomly generated token.

### The container repeatedly restarts

```sh
docker compose logs mnemosyne
docker compose config
```

A non-loopback SSE bind is intentionally rejected by Mnemosyne when the token is missing.

### The service is not healthy

```sh
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q mnemosyne)"
```

The health check confirms that the MCP server accepts TCP connections on port 8080 inside the container. Initial image startup and embedding initialization can be slower on resource-constrained hosts.

### Permission errors with a bind mount

The image runs as UID and GID `10001`. If the named volume is replaced with a host bind mount, make the host directory writable by that identity.

## Security

The Compose service requires bearer authentication, runs as a non-root user, drops all Linux capabilities, and enables `no-new-privileges`. It is publicly reachable by default, so use a firewall and a TLS reverse proxy while retaining bearer authentication before making it available beyond a trusted network.

Mnemosyne is distributed under the MIT License. See the [upstream project](https://github.com/mnemosyne-oss/mnemosyne) for its source and license.
