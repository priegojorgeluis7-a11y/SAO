param(
  [string]$DatabaseUrl = $env:DATABASE_URL
)

if (-not $DatabaseUrl) {
  throw "DATABASE_URL is not set. Pass -DatabaseUrl or set env var."
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  $env:DATABASE_URL = $DatabaseUrl
  alembic downgrade base
  alembic upgrade head
  Write-Output "Migrations reset complete."
} finally {
  Pop-Location
}
