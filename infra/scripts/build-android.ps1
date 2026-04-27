param(
  [string]$ApiBaseUrl = "http://10.0.2.2:8000",
  [ValidateSet("debug", "profile", "release")]
  [string]$Mode = "debug"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

Push-Location (Join-Path $root "apps\user_app")
try {
  flutter build apk "--$Mode" --dart-define "ECG_API_BASE_URL=$ApiBaseUrl"
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "Android APK build completed for apps/user_app in $Mode mode."
