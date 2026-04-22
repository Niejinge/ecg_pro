$composeFile = Join-Path $PSScriptRoot "..\docker\docker-compose.yml"
docker compose -f $composeFile down

