param(
    [string]$ProjectRoot = "..",
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

    throw "$CommandName no fue encontrado. Instala Inno Setup 6."
}

$bundleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerScript = Join-Path $bundleRoot "sao_desktop_instalador.iss"

Push-Location $ProjectRoot
try {
    Set-Location "desktop_flutter\sao_desktop"
    if (Test-Path "build\windows") {
        Remove-Item "build\windows" -Recurse -Force -ErrorAction SilentlyContinue
    }
    flutter clean
    flutter pub get
    flutter build windows --release
    Set-Location $ProjectRoot

    $iscc = Resolve-Tool -CommandName $InnoSetupCompiler -FallbackPaths @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )

    Push-Location $bundleRoot
    try {
        & $iscc $installerScript
        if ($LASTEXITCODE -ne 0) {
            throw "La generación del instalador falló con código $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }

    $installerPath = Join-Path $PWD "desktop_flutter\sao_desktop\build\windows\installer\SAO_Desktop_Setup.exe"
    if (-not (Test-Path $installerPath)) {
        throw "No se encontró el instalador final en la ruta esperada"
    }

    Write-Host "Instalador generado correctamente" -ForegroundColor Green
    Write-Host $installerPath
}
finally {
    Pop-Location
}
