param(
  [string]$DatabaseUrl = $env:DATABASE_URL,
  [string]$VersionId = "v1_2026_02_18"
)

if (-not $DatabaseUrl) {
  throw "DATABASE_URL is not set. Pass -DatabaseUrl or set env var."
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  $env:DATABASE_URL = $DatabaseUrl
  alembic upgrade head
  python database/import_catalog.py --database-url $DatabaseUrl --version-id $VersionId
  Write-Output "Catalog bootstrap complete."
} finally {
  Pop-Location
}
