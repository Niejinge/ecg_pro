param(
  [string]$ApiBaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

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

function Sync-Directory {
  param(
    [string]$Source,
    [string]$Destination
  )

  $rootPath = [System.IO.Path]::GetFullPath($root)
  $destinationPath = [System.IO.Path]::GetFullPath($Destination)

  if (-not $destinationPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to sync outside workspace: $destinationPath"
  }

  if (-not (Test-Path $Source)) {
    throw "Build output does not exist: $Source"
  }

  if (-not (Test-Path $destinationPath)) {
    New-Item -ItemType Directory -Path $destinationPath | Out-Null
  }

  Get-ChildItem -LiteralPath $destinationPath -Force |
    Where-Object { $_.Name -ne ".gitkeep" } |
    Remove-Item -Recurse -Force
  Copy-Item -Path (Join-Path $Source "*") -Destination $destinationPath -Recurse -Force
}

function Disable-FlutterServiceWorker {
  param([string]$BuildPath)

  $bootstrapPath = Join-Path $BuildPath "flutter_bootstrap.js"
  if (-not (Test-Path $bootstrapPath)) {
    return
  }

  $content = Get-Content -LiteralPath $bootstrapPath -Raw
  $content = [regex]::Replace(
    $content,
    "serviceWorkerSettings:\s*\{[\s\S]*?\}\s*",
    "serviceWorkerSettings: null"
  )
  Set-Content -LiteralPath $bootstrapPath -Value $content -Encoding UTF8
}

Write-Host "==> Building user web app"
Invoke-InPath (Join-Path $root "apps\user_app") {
  flutter build web --dart-define "ECG_API_BASE_URL=$ApiBaseUrl"
}
Disable-FlutterServiceWorker (Join-Path $root "apps\user_app\build\web")

Write-Host ""
Write-Host "==> Building admin web app"
Invoke-InPath (Join-Path $root "apps\admin_app") {
  flutter build web --base-href /admin/ --dart-define "ECG_API_BASE_URL=$ApiBaseUrl"
}
Disable-FlutterServiceWorker (Join-Path $root "apps\admin_app\build\web")

Write-Host ""
Write-Host "==> Syncing web builds to infra/nginx/html"
Sync-Directory `
  -Source (Join-Path $root "apps\user_app\build\web") `
  -Destination (Join-Path $root "infra\nginx\html\user")
Sync-Directory `
  -Source (Join-Path $root "apps\admin_app\build\web") `
  -Destination (Join-Path $root "infra\nginx\html\admin")

Write-Host ""
Write-Host "Web builds are ready for Docker/Nginx at http://localhost:8080 and http://localhost:8080/admin/."
