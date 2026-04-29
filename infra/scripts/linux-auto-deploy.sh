#!/usr/bin/env sh
set -eu

ROOT_DIR=${ECG_PRO_ROOT:-/root/niegehejin/ecg_pro}
BRANCH=${ECG_PRO_BRANCH:-main}
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}
COMPOSE_FILE=${COMPOSE_FILE:-"$ROOT_DIR/infra/docker/docker-compose.static.yml"}
LOCK_DIR=${LOCK_DIR:-/tmp/ecg-pro-auto-deploy.lock}
BUILD_FRONTEND=${ECG_BUILD_FRONTEND:-auto}
ASSETS_BRANCH=${ECG_WEB_ASSETS_BRANCH:-web-assets}
ASSETS_REV_FILE=${ECG_WEB_ASSETS_REV_FILE:-"$ROOT_DIR/infra/docker/data/web-assets.rev"}

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
git fetch origin "$ASSETS_BRANCH" || true

deploy_web_assets() {
  assets_revision=$(git rev-parse --verify "origin/$ASSETS_BRANCH" 2>/dev/null || true)
  if [ -z "$assets_revision" ]; then
    log "web assets branch origin/$ASSETS_BRANCH is not available"
    return 1
  fi

  current_assets_revision=$(cat "$ASSETS_REV_FILE" 2>/dev/null || true)
  if [ "$assets_revision" = "$current_assets_revision" ] && [ -f "$ROOT_DIR/infra/nginx/html/user/index.html" ] && [ -f "$ROOT_DIR/infra/nginx/html/admin/index.html" ]; then
    return 2
  fi

  mkdir -p "$ROOT_DIR/tmp" "$ROOT_DIR/infra/nginx/html" "$(dirname "$ASSETS_REV_FILE")"
  git show "origin/$ASSETS_BRANCH:web-assets.tar.gz" > "$ROOT_DIR/tmp/web-assets.tar.gz"
  rm -rf "$ROOT_DIR/infra/nginx/html/user" "$ROOT_DIR/infra/nginx/html/admin"
  tar -xzf "$ROOT_DIR/tmp/web-assets.tar.gz" -C "$ROOT_DIR/infra/nginx/html"
  printf '%s\n' "$assets_revision" > "$ASSETS_REV_FILE"
  log "deployed web assets $assets_revision"
  return 0
}

local_revision=$(git rev-parse HEAD)
remote_revision=$(git rev-parse "origin/$BRANCH")

if [ "$local_revision" = "$remote_revision" ]; then
  mkdir -p "$ROOT_DIR/infra/docker/data/postgres"
  mkdir -p "$ROOT_DIR/infra/docker/data/storage"
  deployment_needed=false
  assets_status=0
  deploy_web_assets || assets_status=$?
  if [ "$assets_status" = "0" ]; then
    deployment_needed=true
  elif [ "$BUILD_FRONTEND" = "always" ] || [ "$BUILD_FRONTEND" = "server" ] || [ ! -f "$ROOT_DIR/infra/nginx/html/user/index.html" ] || [ ! -f "$ROOT_DIR/infra/nginx/html/admin/index.html" ]; then
    log "building Flutter web assets"
    ENV_FILE="$ENV_FILE" COMPOSE_FILE="$COMPOSE_FILE" "$ROOT_DIR/infra/scripts/linux-build-web.sh"
    deployment_needed=true
  fi
  if [ "$deployment_needed" = "true" ]; then
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
    log "deployment complete"
  fi
  log "no changes on origin/$BRANCH"
  exit 0
fi

changed_files=$(git diff --name-only "$local_revision" "$remote_revision" || true)
log "deploying $local_revision -> $remote_revision"

git pull --ff-only origin "$BRANCH"

frontend_changed=false
if printf '%s\n' "$changed_files" | grep -Eq '^(apps/|packages/)'; then
  frontend_changed=true
fi

mkdir -p "$ROOT_DIR/infra/docker/data/postgres"
mkdir -p "$ROOT_DIR/infra/docker/data/storage"

assets_status=0
deploy_web_assets || assets_status=$?
if [ "$assets_status" = "0" ] || [ "$BUILD_FRONTEND" = "off" ]; then
  :
elif [ "$BUILD_FRONTEND" = "always" ] || [ "$BUILD_FRONTEND" = "server" ] || [ ! -f "$ROOT_DIR/infra/nginx/html/user/index.html" ] || [ ! -f "$ROOT_DIR/infra/nginx/html/admin/index.html" ]; then
  log "building Flutter web assets"
  ENV_FILE="$ENV_FILE" COMPOSE_FILE="$COMPOSE_FILE" "$ROOT_DIR/infra/scripts/linux-build-web.sh"
elif [ "$frontend_changed" = "true" ]; then
  log "frontend source changed; waiting for GitHub Actions to publish origin/$ASSETS_BRANCH"
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
log "deployment complete"
