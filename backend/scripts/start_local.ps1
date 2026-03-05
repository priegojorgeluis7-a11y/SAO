<#
.SYNOPSIS
    Inicia el backend SAO en modo 100% local (SQLite + almacenamiento en disco).
    Sin dependencias de GCP, Cloud SQL ni GCS.

.PARAMETER ResetDb
    Si $true (default), elimina la DB SQLite antes de arrancar y re-corre seeds.

.PARAMETER Port
    Puerto en el que escucha uvicorn (default: 8000).

.EXAMPLE
    # Primera vez (DB limpia + seeds):
    .\start_local.ps1

    # Reutilizar DB existente (más rápido):
    .\start_local.ps1 -ResetDb $false
#>
param(
    [bool]$ResetDb = $true,
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

# ── Entorno local ────────────────────────────────────────────────────────────
$env:DATABASE_URL              = 'sqlite:///./sao_local.db'
$env:JWT_SECRET                = 'dev-local-secret-change-in-production'
$env:GCS_BUCKET                = 'local'
$env:ENV                       = 'development'
$env:EVIDENCE_STORAGE_BACKEND  = 'local'
$env:LOCAL_BASE_URL            = "http://localhost:$Port"
$env:LOCAL_UPLOADS_DIR         = './uploads'
$env:CORS_ORIGINS              = "http://localhost:$Port,http://localhost:3000,http://localhost:5173"
$env:SIGNUP_INVITE_CODE        = 'SAO2026'
$env:ADMIN_INVITE_CODE         = 'ADMIN2026'
$env:SAO_SKIP_EFFECTIVE_CATALOG_SEED = '0'

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗"
Write-Host "║   SAO Backend — Modo Local                   ║"
Write-Host "╠══════════════════════════════════════════════╣"
Write-Host "║  DB:        SQLite (sao_local.db)            ║"
Write-Host "║  Evidencias: disco local (./uploads/)        ║"
Write-Host "║  API:       http://localhost:$Port           ║"
Write-Host "╚══════════════════════════════════════════════╝"
Write-Host ""

# ── Reset de DB ──────────────────────────────────────────────────────────────
if ($ResetDb -and (Test-Path 'sao_local.db')) {
    Write-Host '[LOCAL] Eliminando DB anterior...'
    Remove-Item 'sao_local.db' -Force
}

if ($ResetDb -and (Test-Path 'uploads')) {
    Write-Host '[LOCAL] Limpiando uploads anteriores...'
    Remove-Item 'uploads' -Recurse -Force
}

# ── Schema ───────────────────────────────────────────────────────────────────
Write-Host '[LOCAL] Creando schema SQLite...'
d:/SAO/.venv/Scripts/python.exe -c @"
import app.models.activity
import app.models.audit_log
import app.models.catalog
import app.models.catalog_effective
import app.models.event
import app.models.evidence
import app.models.front
import app.models.location
import app.models.observation
import app.models.permission
import app.models.project
import app.models.project_location_scope
import app.models.reject_reason
import app.models.role
import app.models.user_role_scope
from app.core.database import Base, engine
Base.metadata.create_all(bind=engine)
print('  schema OK')
"@

# ── Seeds ────────────────────────────────────────────────────────────────────
Write-Host '[LOCAL] Ejecutando seeds (catálogo TMQ + usuario admin)...'
d:/SAO/.venv/Scripts/python.exe -m app.seeds.initial_data

Write-Host ""
Write-Host "[LOCAL] ✅ Backend listo en http://localhost:$Port"
Write-Host "[LOCAL]    Docs:   http://localhost:$Port/api/v1/openapi.json"
Write-Host "[LOCAL]    Health: http://localhost:$Port/health"
Write-Host "[LOCAL]    Invite: SAO2026 / admin: ADMIN2026"
Write-Host ""

# ── Servidor ─────────────────────────────────────────────────────────────────
d:/SAO/.venv/Scripts/python.exe -m uvicorn app.main:app `
    --host 127.0.0.1 `
    --port $Port `
    --reload
