#!/bin/sh
set -eu

echo "Waiting for database..."
python - <<'PY'
import sys
import time

from sqlalchemy import text

from app.db.session import engine

for attempt in range(1, 31):
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        print("Database is ready.")
        sys.exit(0)
    except Exception as exc:
        print(f"Database not ready yet ({attempt}/30): {exc}")
        time.sleep(2)

print("Database did not become ready in time.", file=sys.stderr)
sys.exit(1)
PY

echo "Running database migrations..."
alembic upgrade head

echo "Bootstrapping default admin..."
python scripts/bootstrap_admin.py

echo "Starting API server..."
if [ "${APP_RELOAD:-false}" = "true" ]; then
  exec uvicorn app.main:app --host "${APP_HOST:-0.0.0.0}" --port "${APP_PORT:-8000}" --reload
fi

exec uvicorn app.main:app --host "${APP_HOST:-0.0.0.0}" --port "${APP_PORT:-8000}"
