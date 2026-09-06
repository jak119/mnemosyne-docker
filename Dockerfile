FROM python:3.12-slim

LABEL org.opencontainers.image.title="Mnemosyne Server"
LABEL org.opencontainers.image.description="Mnemosyne MCP and Sync server"
LABEL org.opencontainers.image.source="https://github.com/jak119/mnemosyne-docker"
LABEL org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/app \
    MNEMOSYNE_DATA_DIR=/data

COPY requirements.txt /tmp/requirements.txt
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN groupadd --system --gid 10001 mnemosyne \
    && useradd --system --uid 10001 --gid mnemosyne --home-dir /app --create-home mnemosyne \
    && python -m pip install --requirement /tmp/requirements.txt \
    && rm /tmp/requirements.txt \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && mkdir -p /data \
    && chown -R mnemosyne:mnemosyne /app /data

WORKDIR /app

USER mnemosyne

VOLUME ["/data"]

EXPOSE 8080 8765

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["python", "-c", "import os, socket, sys\nfor p in [int(os.getenv('MNEMOSYNE_PORT', 8080)), int(os.getenv('MNEMOSYNE_SYNC_PORT', 8765))]:\n    try:\n        s = socket.create_connection(('127.0.0.1', p), timeout=3)\n        s.close()\n        sys.exit(0)\n    except OSError:\n        pass\nsys.exit(1)"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["mcp", "--transport", "sse", "--host", "0.0.0.0", "--port", "8080"]
