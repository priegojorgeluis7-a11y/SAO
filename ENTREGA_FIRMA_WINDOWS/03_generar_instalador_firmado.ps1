param(
    [string]$ProjectRoot = "..",
    [string]$PfxPath = ".\certificados\sao-internal-code-signing.pfx",
    [string]$PfxPassword,
    [string]$InnoSetupCompiler = "iscc.exe"
)

$ErrorActionPreference = 'Stop'

function Resolve-Tool {
    param(
        [string]$CommandName,
        [string[]]$FallbackPaths = @()
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return (Get-Command $CommandName).Source
    }

    foreach ($path in $FallbackPaths) {
        if (Test-Path $path) { return $path }
    }

    throw "$CommandName no fue encontrado"
}

$bundleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$signScript = Join-Path $bundleRoot "02_firmar_app_windows.ps1"
$installerScript = Join-Path $bundleRoot "sao_desktop_internal_installer.iss"

if (-not $PfxPassword) { throw "Falta el parámetro PfxPassword" }
if (-not (Test-Path $PfxPath)) { throw "No existe el PFX: $PfxPath" }

& $signScript -ProjectRoot $ProjectRoot -PfxPath $PfxPath -PfxPassword $PfxPassword
if ($LASTEXITCODE -ne 0) { throw "Falló la firma del ejecutable" }

$iscc = Resolve-Tool -CommandName $InnoSetupCompiler -FallbackPaths @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)

Push-Location $bundleRoot
try {
    & $iscc $installerScript
    if ($LASTEXITCODE -ne 0) { throw "Falló la generación del instalador" }
}
finally {
    Pop-Location
}

$installerPath = Join-Path $ProjectRoot "desktop_flutter\sao_desktop\build\windows\installer\SAO_Desktop_Internal_Setup.exe"
if (-not (Test-Path $installerPath)) { throw "No se generó el instalador esperado" }

$signTool = Resolve-Tool -CommandName "signtool.exe" -FallbackPaths @()
& $signTool sign /fd SHA256 /f $PfxPath /p $PfxPassword $installerPath
if ($LASTEXITCODE -ne 0) { throw "Falló la firma del instalador" }

& $signTool verify /pa /v $installerPath
if ($LASTEXITCODE -ne 0) { throw "Falló la verificación del instalador" }

Write-Host "Instalador interno listo" -ForegroundColor Green
Write-Host (Resolve-Path $installerPath)
