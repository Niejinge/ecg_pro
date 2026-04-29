param(
  [string]$BaseUrl = "http://localhost:8080",
  [string]$ApiUrl = "http://localhost:8000",
  [string]$AdminUsername = "niegehedao",
  [string]$AdminPassword = "niegehedao123",
  [switch]$SeedDemoData
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Command
}

function Invoke-JsonGet {
  param([string]$Uri)

  $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
  return $response.Content | ConvertFrom-Json
}

if ($SeedDemoData) {
  Invoke-Step "Seed demo data" {
    docker exec ecg_pro_api python scripts/seed_demo_data.py
  }
}

Invoke-Step "Check API health through Nginx" {
  $health = Invoke-JsonGet "$BaseUrl/health"
  if ($health.status -ne "ok") {
    throw "Unexpected health status: $($health | ConvertTo-Json -Compress)"
  }
  Write-Host "Health OK: $($health.service)"
}

Invoke-Step "Check direct API docs" {
  $response = Invoke-WebRequest -Uri "$ApiUrl/docs" -UseBasicParsing
  if ($response.StatusCode -ne 200) {
    throw "API docs returned $($response.StatusCode)"
  }
  Write-Host "API docs OK"
}

Invoke-Step "Check user web assets" {
  foreach ($path in @("/", "/flutter_bootstrap.js", "/main.dart.js")) {
    $response = Invoke-WebRequest -Uri "$BaseUrl$path" -UseBasicParsing
    if ($response.StatusCode -ne 200) {
      throw "User asset $path returned $($response.StatusCode)"
    }
  }
  Write-Host "User web assets OK"
}

Invoke-Step "Check admin web assets" {
  foreach ($path in @("/admin/", "/admin/flutter_bootstrap.js", "/admin/main.dart.js")) {
    $response = Invoke-WebRequest -Uri "$BaseUrl$path" -UseBasicParsing
    if ($response.StatusCode -ne 200) {
      throw "Admin asset $path returned $($response.StatusCode)"
    }
  }
  Write-Host "Admin web assets OK"
}

Invoke-Step "Check public case API" {
  $cases = Invoke-JsonGet "$BaseUrl/api/v1/public/cases?page=1&page_size=2"
  if ($cases.total -lt 1) {
    throw "Expected at least one public case. Run with -SeedDemoData if needed."
  }
  Write-Host "Public cases OK: total=$($cases.total)"
}

Invoke-Step "Check admin login API" {
  $body = @{
    username = $AdminUsername
    password = $AdminPassword
  } | ConvertTo-Json

  $response = Invoke-WebRequest `
    -Uri "$BaseUrl/api/v1/auth/login" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body `
    -UseBasicParsing
  $payload = $response.Content | ConvertFrom-Json

  if (-not $payload.access_token) {
    throw "Login response did not include an access token."
  }
  Write-Host "Admin login OK: $($payload.user.username)"
}

Write-Host ""
Write-Host "Docker smoke checks completed."
