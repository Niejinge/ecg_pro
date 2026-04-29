#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}
COMPOSE_FILE=${COMPOSE_FILE:-"$ROOT_DIR/infra/docker/docker-compose.prod.yml"}

if [ ! -f "$ENV_FILE" ]; then
  cp "$ROOT_DIR/.env.production.example" "$ENV_FILE"
  echo "Created $ENV_FILE from .env.production.example."
  echo "Edit secrets and PUBLIC_BASE_URL, then run this script again."
  exit 1
fi

mkdir -p "$ROOT_DIR/infra/docker/data/postgres"
mkdir -p "$ROOT_DIR/infra/docker/data/storage"

if [ "${ECG_BUILD_FRONTEND:-0}" = "1" ]; then
  ENV_FILE="$ENV_FILE" COMPOSE_FILE="$COMPOSE_FILE" "$ROOT_DIR/infra/scripts/linux-build-web.sh"
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
