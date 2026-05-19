<#
.SYNOPSIS
    Un-click: compila SAO Desktop para Windows y genera el instalador de produccion.

.DESCRIPTION
    Ejecutar desde PowerShell en la raiz del proyecto (desktop_flutter\sao_desktop\):

        .\build_windows_prod.ps1

    El instalador queda en:
        build\windows\installer\SAO_Desktop_Internal_Setup.exe

    Requisitos en la maquina Windows:
        - Flutter SDK (canal stable, >= 3.19) con target windows habilitado
            https://docs.flutter.dev/get-started/install/windows/desktop
        - Visual Studio 2022 con workload "Desktop development with C++"
            (o Build Tools equivalente con componente CMake)
        - Inno Setup 6
            https://jrsoftware.org/isdl.php

    Verificar Flutter windows habilitado:
        flutter config --enable-windows-desktop
        flutter doctor -v
#>

$ErrorActionPreference = 'Stop'

# URL de produccion Cloud Run — actualizar si el servicio cambia de region/proyecto
$BACKEND_URL = "https://sao-api-97150883570.us-central1.run.app"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BuildScript = Join-Path $ScriptDir "scripts\windows\build_installer.ps1"

if (-not (Test-Path $BuildScript)) {
    throw "No se encontro el script de build: $BuildScript"
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  SAO Desktop — Instalador Windows (PROD)"   -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Backend : $BACKEND_URL"
Write-Host ""

& $BuildScript -BackendUrl $BACKEND_URL
