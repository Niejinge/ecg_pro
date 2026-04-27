param(
  [switch]$IncludeBuilds,
  [switch]$IncludeAndroidBuild,
  [string]$WebApiBaseUrl = "http://localhost:8080",
  [string]$AndroidApiBaseUrl = "http://10.0.2.2:8000"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Command
}

function Invoke-InPath {
  param(
    [string]$Path,
    [scriptblock]$Command
  )

  Push-Location $Path
  try {
    & $Command
  }
  finally {
    Pop-Location
  }
}

$python = "python"
$venvPython = Join-Path $root "services\api\.venv\Scripts\python.exe"
if (Test-Path $venvPython) {
  $python = $venvPython
}

Invoke-Step "Backend pytest" {
  Invoke-InPath (Join-Path $root "services\api") {
    & $python -m pytest -q
  }
}

foreach ($package in @("ecg_core", "ecg_api")) {
  Invoke-Step "Dart analyze/test packages/$package" {
    Invoke-InPath (Join-Path $root "packages\$package") {
      dart analyze
      dart test
    }
  }
}

Invoke-Step "Flutter analyze/test packages/ecg_ui" {
  Invoke-InPath (Join-Path $root "packages\ecg_ui") {
    flutter analyze
    flutter test
  }
}

foreach ($app in @("user_app", "admin_app")) {
  Invoke-Step "Flutter analyze/test apps/$app" {
    Invoke-InPath (Join-Path $root "apps\$app") {
      flutter analyze
      flutter test
    }
  }
}

if ($IncludeBuilds) {
  Invoke-Step "Flutter web build apps/user_app" {
    Invoke-InPath (Join-Path $root "apps\user_app") {
      flutter build web --dart-define "ECG_API_BASE_URL=$WebApiBaseUrl"
    }
  }

  Invoke-Step "Flutter web build apps/admin_app" {
    Invoke-InPath (Join-Path $root "apps\admin_app") {
      flutter build web --base-href /admin/ --dart-define "ECG_API_BASE_URL=$WebApiBaseUrl"
    }
  }
}

if ($IncludeAndroidBuild) {
  Invoke-Step "Flutter Android debug APK build apps/user_app" {
    Invoke-InPath (Join-Path $root "apps\user_app") {
      flutter build apk --debug --dart-define "ECG_API_BASE_URL=$AndroidApiBaseUrl"
    }
  }
}

Write-Host ""
Write-Host "All requested checks completed."
