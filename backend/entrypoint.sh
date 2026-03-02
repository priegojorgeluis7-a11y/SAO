#!/bin/sh
# Entrypoint: wait for Cloud SQL socket, run migrations+seeds, start server.
set -e

# Wait for Cloud SQL unix socket (Cloud Run sidecar may take a few seconds to create it)
if [ -n "$CLOUDSQL_INSTANCE" ]; then
    SOCKET="/cloudsql/${CLOUDSQL_INSTANCE}/.s.PGSQL.5432"
    echo "Waiting for Cloud SQL socket: $SOCKET"
    i=0
    while [ ! -S "$SOCKET" ]; do
        i=$((i + 1))
        if [ "$i" -gt 30 ]; then
            echo "ERROR: Cloud SQL socket not ready after 30s"
            exit 1
        fi
        echo "  attempt $i/30..."
        sleep 1
    done
    echo "Cloud SQL socket ready."
fi

echo "Running migrations and seeds..."
python scripts/run_migrations_and_seed.py

echo "Starting uvicorn..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8080}"
