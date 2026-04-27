param(
  [switch]$Detached
)

$ErrorActionPreference = "Stop"

$composeFile = Join-Path $PSScriptRoot "..\docker\docker-compose.yml"

if ($Detached) {
  docker compose -f $composeFile up --build -d
}
else {
  docker compose -f $composeFile up --build
}
