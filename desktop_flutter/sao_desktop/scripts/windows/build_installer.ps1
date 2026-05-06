<#
.SYNOPSIS
    Compila SAO Desktop para Windows y genera el instalador con Inno Setup.

.DESCRIPTION
    Ejecutar desde la raíz del proyecto sao_desktop:
        .\scripts\windows\build_installer.ps1 -BackendUrl "https://sao-api-97150883570.us-central1.run.app"

    Requisitos en la máquina Windows:
        - Flutter SDK (canal stable, >= 3.10) con target windows habilitado
        - Inno Setup 6 instalado en la ruta por defecto
        - Visual Studio 2022 con "Desktop development with C++" o Build Tools equivalente

.PARAMETER BackendUrl
    URL del backend Cloud Run. Obligatorio.

.PARAMETER InnoSetupCompiler
    Ruta a ISCC.exe. Por defecto detecta la instalación estándar de Inno Setup 6.

.PARAMETER OutputDir
    Directorio donde se dejará el instalador final. Por defecto build\windows\installer.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BackendUrl,

    [string]$InnoSetupCompiler = "",
    [string]$OutputDir = "build\windows\installer"
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path

function Find-Tool {
    param([string]$Name, [string[]]$Fallbacks = @())
    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        return (Get-Command $Name).Source
    }
    foreach ($g in $Fallbacks) {
        $hit = Get-ChildItem -Path $g -ErrorAction SilentlyContinue |
               Sort-Object FullName -Descending |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

Push-Location $ProjectRoot
try {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  SAO Desktop — Windows Build & Installer"       -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  Backend URL : $BackendUrl"
    Write-Host "  Project root: $ProjectRoot"
    Write-Host ""

    # ── 1. Verificar Flutter ──────────────────────────────────────────────────
    $flutter = Find-Tool "flutter"
    if (-not $flutter) { throw "flutter no encontrado en PATH. Instala Flutter SDK." }
    Write-Host "[1/4] Flutter OK: $flutter" -ForegroundColor Green

    # ── 2. Build Release ──────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[2/4] Compilando Flutter Windows (release)..." -ForegroundColor Cyan

    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get falló." }

    & $flutter build windows --release `
        --dart-define=SAO_BACKEND_URL=$BackendUrl
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows falló." }

    $exePath = Join-Path $ProjectRoot "build\windows\x64\runner\Release\sao_desktop.exe"
    if (-not (Test-Path $exePath)) {
        throw "Ejecutable no generado en: $exePath"
    }
    Write-Host "  Ejecutable listo: $exePath" -ForegroundColor Green

    # ── 3. Inno Setup ─────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[3/4] Generando instalador con Inno Setup..." -ForegroundColor Cyan

    if (-not $InnoSetupCompiler) {
        $InnoSetupCompiler = Find-Tool "iscc" -Fallbacks @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
        )
    }
    if (-not $InnoSetupCompiler) {
        throw "Inno Setup 6 no encontrado. Descárgalo de https://jrsoftware.org/isdl.php"
    }

    $issScript = Join-Path $ScriptDir "sao_desktop_internal_installer.iss"
    if (-not (Test-Path $issScript)) {
        throw "Script Inno Setup no encontrado: $issScript"
    }

    New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot $OutputDir) | Out-Null

    & $InnoSetupCompiler $issScript
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup falló con código $LASTEXITCODE" }

    $installerPath = Join-Path $ProjectRoot "$OutputDir\SAO_Desktop_Internal_Setup.exe"
    if (-not (Test-Path $installerPath)) {
        throw "Instalador no generado en: $installerPath"
    }

    # ── 4. Resumen ────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "[4/4] ¡Listo!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Instalador:" -ForegroundColor White
    Write-Host "  $installerPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Distribuye ese archivo a los usuarios." -ForegroundColor White
    Write-Host ""
}
finally {
    Pop-Location
}
