#!/usr/bin/env sh
set -eu

ROOT_DIR=${ECG_PRO_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}
COMPOSE_FILE=${COMPOSE_FILE:-"$ROOT_DIR/infra/docker/docker-compose.static.yml"}

if [ -x /opt/flutter/bin/flutter ] && [ -z "${FLUTTER_BIN:-}" ]; then
  FLUTTER_BIN=/opt/flutter/bin/flutter
else
  FLUTTER_BIN=${FLUTTER_BIN:-flutter}
fi

export PUB_HOSTED_URL=${PUB_HOSTED_URL:-https://pub.flutter-io.cn}
export FLUTTER_STORAGE_BASE_URL=${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "Flutter is not installed. Install it to /opt/flutter or set FLUTTER_BIN." >&2
  exit 1
fi

if [ -z "${ECG_API_BASE_URL:-}" ] && [ -f "$ENV_FILE" ]; then
  ECG_API_BASE_URL=$(sed -n 's/^PUBLIC_BASE_URL=//p' "$ENV_FILE" | tail -n 1 | sed 's/^"//; s/"$//')
fi

if [ -z "${ECG_API_BASE_URL:-}" ]; then
  echo "ECG_API_BASE_URL or PUBLIC_BASE_URL is required for Flutter web builds." >&2
  exit 1
fi

disable_flutter_service_worker() {
  build_path=$1
  bootstrap_path="$build_path/flutter_bootstrap.js"
  if [ ! -f "$bootstrap_path" ]; then
    return 0
  fi
  python3 - "$bootstrap_path" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
content = re.sub(
    r"serviceWorkerSettings:\s*\{[\s\S]*?\}\s*",
    "serviceWorkerSettings: null",
    content,
)
path.write_text(content, encoding="utf-8")
PY
}

sync_directory() {
  source_dir=$1
  target_dir=$2
  if [ ! -d "$source_dir" ]; then
    echo "Build output does not exist: $source_dir" >&2
    exit 1
  fi
  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp -a "$source_dir"/. "$target_dir"/
}

echo "==> Building user web app with API: $ECG_API_BASE_URL"
(
  cd "$ROOT_DIR/apps/user_app"
  "$FLUTTER_BIN" pub get
  "$FLUTTER_BIN" build web --release --dart-define "ECG_API_BASE_URL=$ECG_API_BASE_URL"
)
disable_flutter_service_worker "$ROOT_DIR/apps/user_app/build/web"

echo "==> Building admin web app with API: $ECG_API_BASE_URL"
(
  cd "$ROOT_DIR/apps/admin_app"
  "$FLUTTER_BIN" pub get
  "$FLUTTER_BIN" build web --release --base-href /admin/ --dart-define "ECG_API_BASE_URL=$ECG_API_BASE_URL"
)
disable_flutter_service_worker "$ROOT_DIR/apps/admin_app/build/web"

echo "==> Syncing web builds to Nginx static directories"
sync_directory "$ROOT_DIR/apps/user_app/build/web" "$ROOT_DIR/infra/nginx/html/user"
sync_directory "$ROOT_DIR/apps/admin_app/build/web" "$ROOT_DIR/infra/nginx/html/admin"

if command -v docker >/dev/null 2>&1 && [ -f "$COMPOSE_FILE" ]; then
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec -T nginx nginx -s reload >/dev/null 2>&1 || true
fi

echo "Flutter web assets are ready."
