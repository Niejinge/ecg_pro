$composeFile = Join-Path $PSScriptRoot "..\docker\docker-compose.yml"
$ErrorActionPreference = "Stop"

docker compose -f $composeFile down
