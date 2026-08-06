FROM python:3.12-slim

LABEL org.opencontainers.image.title="Mnemosyne MCP Server"
LABEL org.opencontainers.image.description="Local Mnemosyne MCP server"
LABEL org.opencontainers.image.source="https://github.com/jak119/mnemosyne-docker"
LABEL org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/app \
    MNEMOSYNE_DATA_DIR=/data

COPY requirements.txt /tmp/requirements.txt

RUN groupadd --system --gid 10001 mnemosyne \
    && useradd --system --uid 10001 --gid mnemosyne --home-dir /app --create-home mnemosyne \
    && python -m pip install --requirement /tmp/requirements.txt \
    && rm /tmp/requirements.txt \
    && mkdir -p /data \
    && chown -R mnemosyne:mnemosyne /app /data

WORKDIR /app

USER mnemosyne

VOLUME ["/data"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["python", "-c", "import socket; s = socket.create_connection(('127.0.0.1', 8080), timeout=3); s.close()"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["mnemosyne", "mcp"]

CMD ["--transport", "sse", "--host", "0.0.0.0", "--port", "8080"]
