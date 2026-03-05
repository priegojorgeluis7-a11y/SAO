param(
    [bool]$ResetDb = $true,
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')

$env:DATABASE_URL = 'sqlite:///./local_dev.db'
$env:JWT_SECRET = 'dev-local-secret'
$env:GCS_BUCKET = 'sao-local-bucket'
$env:SAO_SKIP_EFFECTIVE_CATALOG_SEED = '1'

if ($ResetDb -and (Test-Path 'local_dev.db')) {
    Remove-Item 'local_dev.db' -Force
}

Write-Host '[LOCAL] Bootstrapping SQLite schema...'
d:/SAO/.venv/Scripts/python.exe -c "import app.models; from app.core.database import Base, engine; Base.metadata.create_all(bind=engine); print('schema_ok')"

Write-Host '[LOCAL] Running seeds (effective catalog skipped)...'
d:/SAO/.venv/Scripts/python.exe -m app.seeds.run_seeds

Write-Host "[LOCAL] Starting API on http://127.0.0.1:$Port"
d:/SAO/.venv/Scripts/python.exe -m uvicorn app.main:app --host 127.0.0.1 --port $Port --reload
