#!/bin/sh
set -e

# If first arg is a flag, default to running mcp with those flags
if [ "${1#-}" != "$1" ]; then
    set -- mcp "$@"
fi

case "$1" in
    sync-serve|sync-server)
        cmd="$1"
        shift

        has_host=0
        has_port=0
        has_auth=0
        has_db=0

        for arg in "$@"; do
            case "$arg" in
                --host*|-h*) has_host=1 ;;
                --port*|-p*) has_port=1 ;;
                --api-key*|--api-key-file*|--jwt-secret*|--jwt-secret-file*) has_auth=1 ;;
                --db-path*) has_db=1 ;;
            esac
        done

        extra_args=""
        if [ "$has_host" = "0" ]; then
            extra_args="$extra_args --host ${MNEMOSYNE_SYNC_HOST:-0.0.0.0}"
        fi
        if [ "$has_port" = "0" ]; then
            extra_args="$extra_args --port ${MNEMOSYNE_SYNC_PORT:-8765}"
        fi
        if [ "$has_db" = "0" ]; then
            extra_args="$extra_args --db-path ${MNEMOSYNE_SYNC_DB_PATH:-${MNEMOSYNE_DATA_DIR:-/data}/mnemosyne.db}"
        fi
        if [ "$has_auth" = "0" ]; then
            if [ -n "${MNEMOSYNE_SYNC_API_KEY_FILE:-}" ]; then
                extra_args="$extra_args --api-key-file $MNEMOSYNE_SYNC_API_KEY_FILE"
            elif [ -n "${MNEMOSYNE_SYNC_API_KEY:-}" ]; then
                extra_args="$extra_args --api-key $MNEMOSYNE_SYNC_API_KEY"
            elif [ -n "${MNEMOSYNE_SYNC_JWT_SECRET_FILE:-}" ]; then
                extra_args="$extra_args --jwt-secret-file $MNEMOSYNE_SYNC_JWT_SECRET_FILE"
            elif [ -n "${MNEMOSYNE_SYNC_JWT_SECRET:-}" ]; then
                extra_args="$extra_args --jwt-secret $MNEMOSYNE_SYNC_JWT_SECRET"
            fi
        fi

        # shellcheck disable=SC2086
        exec mnemosyne "$cmd" $extra_args "$@"
        ;;

    sync|sync-init|sync-status)
        cmd="$1"
        shift

        has_db=0
        for arg in "$@"; do
            case "$arg" in
                --db-path*) has_db=1 ;;
            esac
        done

        extra_args=""
        if [ "$has_db" = "0" ]; then
            extra_args="$extra_args --db-path ${MNEMOSYNE_SYNC_DB_PATH:-${MNEMOSYNE_DATA_DIR:-/data}/mnemosyne.db}"
        fi

        # shellcheck disable=SC2086
        exec mnemosyne "$cmd" $extra_args "$@"
        ;;

    mcp|sync-generate-key|export|import|import-hindsight|verify|doctor|diagnose|repair|reindex|stats|sleep|remember|store|recall|search|update|edit|delete|forget|bank|migrate|hygiene|profile|config|backups|backup|restore)
        exec mnemosyne "$@"
        ;;

    mnemosyne)
        shift
        exec "$0" "$@"
        ;;

    *)
        exec "$@"
        ;;
esac
