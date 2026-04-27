# Demo Runbook

This runbook describes how to verify and run the ECG Pro MVP demo locally.

## Goals

- Keep backend, Flutter packages, user app, and admin app verifiable with one command.
- Build web assets that can be served by Docker/Nginx.
- Build an Android APK for local device or emulator testing.
- Keep Figma or other design tools optional for the MVP.

## Full Local Verification

Run the default automated checks:

```powershell
.\infra\scripts\verify-all.ps1
```

This runs:

- Backend `pytest`.
- `dart analyze` and `dart test` for pure Dart packages.
- `flutter analyze` and `flutter test` for Flutter package/app targets.

Include web builds:

```powershell
.\infra\scripts\verify-all.ps1 -IncludeBuilds
```

Include Android debug APK build:

```powershell
.\infra\scripts\verify-all.ps1 -IncludeAndroidBuild
```

## Web Demo Build

Build both Flutter web apps and sync them into the Nginx static directories:

```powershell
.\infra\scripts\build-web.ps1
```

Generated files under `infra/nginx/html/user` and `infra/nginx/html/admin` are
local demo artifacts and should not be committed.

The default API base URL is `http://localhost:8080`, which works with the Nginx
reverse proxy in Docker Compose.

Use a custom API base URL if needed:

```powershell
.\infra\scripts\build-web.ps1 -ApiBaseUrl "http://localhost:8000"
```

## Docker Demo

Before starting the stack, make sure Docker Desktop is running and the Linux
engine is available.

Start the Docker stack:

```powershell
.\infra\scripts\dev-up.ps1
```

The API container waits for PostgreSQL, runs Alembic migrations, and bootstraps
the default admin account before starting Uvicorn.

Useful URLs:

- User web app: `http://localhost:8080/`
- Admin web app: `http://localhost:8080/admin/`
- API health check: `http://localhost:8080/health`
- API docs: `http://localhost:8000/docs`
- MinIO console: `http://localhost:9001`

Run smoke checks after the stack starts:

```powershell
.\infra\scripts\smoke-docker.ps1
```

If the database has not been seeded yet:

```powershell
.\infra\scripts\smoke-docker.ps1 -SeedDemoData
```

Stop the Docker stack:

```powershell
.\infra\scripts\dev-down.ps1
```

## Demo Data

After the Docker stack is running, seed demo content inside the API container:

```powershell
docker exec ecg_pro_api python scripts\seed_demo_data.py
```

For local backend development outside Docker, seed from the backend project:

```powershell
cd services\api
python scripts\seed_demo_data.py
```

If the local backend virtual environment exists, prefer:

```powershell
cd services\api
.\.venv\Scripts\python.exe scripts\seed_demo_data.py
```

## Android Demo Build

Build a debug APK:

```powershell
.\infra\scripts\build-android.ps1
```

The debug APK is written to
`apps/user_app/build/app/outputs/flutter-apk/app-debug.apk`.

The default Android API base URL is `http://10.0.2.2:8000`, which targets a
backend running on the host machine from the Android emulator.

For a physical device, pass the host LAN IP:

```powershell
.\infra\scripts\build-android.ps1 -ApiBaseUrl "http://192.168.1.10:8000"
```

## Acceptance Checklist

- `verify-all.ps1` passes.
- `build-web.ps1` completes and updates `infra/nginx/html`.
- Docker stack serves the user app, admin app, and `/health`.
- Android debug APK builds successfully.
- Any new feature stage adds or updates relevant tests before commit.
