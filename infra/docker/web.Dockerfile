FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG ECG_API_BASE_URL=http://localhost

WORKDIR /workspace

COPY packages/ /workspace/packages/
COPY apps/user_app/ /workspace/apps/user_app/
COPY apps/admin_app/ /workspace/apps/admin_app/

RUN cd apps/user_app && \
    flutter pub get && \
    flutter build web --release --dart-define "ECG_API_BASE_URL=${ECG_API_BASE_URL}"

RUN cd apps/admin_app && \
    flutter pub get && \
    flutter build web --release --base-href /admin/ --dart-define "ECG_API_BASE_URL=${ECG_API_BASE_URL}"

RUN python3 - <<'PY'
from pathlib import Path
import re

for build_dir in (Path("apps/user_app/build/web"), Path("apps/admin_app/build/web")):
    bootstrap = build_dir / "flutter_bootstrap.js"
    if not bootstrap.exists():
        continue
    content = bootstrap.read_text(encoding="utf-8")
    content = re.sub(
        r"serviceWorkerSettings:\s*\{[\s\S]*?\}\s*",
        "serviceWorkerSettings: null",
        content,
    )
    bootstrap.write_text(content, encoding="utf-8")
PY

FROM nginx:1.27-alpine

COPY infra/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/apps/user_app/build/web/ /usr/share/nginx/html/user/
COPY --from=build /workspace/apps/admin_app/build/web/ /usr/share/nginx/html/admin/
