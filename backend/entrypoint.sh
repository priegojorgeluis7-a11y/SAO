#!/bin/sh
# Entrypoint for firestore-only runtime.
set -e

DATA_BACKEND="${DATA_BACKEND:-firestore}"
if [ "$DATA_BACKEND" != "firestore" ]; then
    echo "ERROR: DATA_BACKEND must be 'firestore' in this image. Got: $DATA_BACKEND"
    exit 1
fi

echo "Starting uvicorn (firestore-only mode)..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8080}"
