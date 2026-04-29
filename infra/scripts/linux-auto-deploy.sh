#!/usr/bin/env sh
set -eu

ROOT_DIR=${ECG_PRO_ROOT:-/root/niegehejin/ecg_pro}
BRANCH=${ECG_PRO_BRANCH:-main}
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}
COMPOSE_FILE=${COMPOSE_FILE:-"$ROOT_DIR/infra/docker/docker-compose.static.yml"}
LOCK_DIR=${LOCK_DIR:-/tmp/ecg-pro-auto-deploy.lock}

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another deployment is already running"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

cd "$ROOT_DIR"

if [ ! -f "$ENV_FILE" ]; then
  log "missing env file: $ENV_FILE"
  exit 1
fi

git fetch origin "$BRANCH"

local_revision=$(git rev-parse HEAD)
remote_revision=$(git rev-parse "origin/$BRANCH")

if [ "$local_revision" = "$remote_revision" ]; then
  log "no changes on origin/$BRANCH"
  exit 0
fi

changed_files=$(git diff --name-only "$local_revision" "$remote_revision" || true)
log "deploying $local_revision -> $remote_revision"

git pull --ff-only origin "$BRANCH"

if printf '%s\n' "$changed_files" | grep -Eq '^(apps/|packages/)'; then
  log "frontend source changed; static web assets must be rebuilt and synced separately for UI changes to appear"
fi

mkdir -p "$ROOT_DIR/infra/docker/data/postgres"
mkdir -p "$ROOT_DIR/infra/docker/data/storage"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
log "deployment complete"
