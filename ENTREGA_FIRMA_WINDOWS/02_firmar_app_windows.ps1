param(
    [string]$ProjectRoot = "..",
    [string]$PfxPath = ".\certificados\sao-internal-code-signing.pfx",
    [string]$PfxPassword,
    [string]$SigntoolPath = "signtool.exe",
    [switch]$SkipBuild,
    [string]$ExePath = "desktop_flutter\sao_desktop\build\windows\x64\runner\Release\sao_desktop.exe"
)

$ErrorActionPreference = 'Stop'

function Resolve-SignTool {
    param([string]$Candidate)
    if (Get-Command $Candidate -ErrorAction SilentlyContinue) {
        return (Get-Command $Candidate).Source
    }
    $kitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path $kitsRoot) {
        $found = Get-ChildItem -Path $kitsRoot -Recurse -Filter signtool.exe | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    throw "signtool.exe no fue encontrado"
}

Push-Location $ProjectRoot
try {
    if (-not $SkipBuild) {
        Set-Location "desktop_flutter\sao_desktop"
        flutter build windows --release
        Set-Location $ProjectRoot
    }

    if (-not (Test-Path $PfxPath)) { throw "No existe el PFX: $PfxPath" }
    if (-not (Test-Path $ExePath)) { throw "No existe el ejecutable: $ExePath" }
    if (-not $PfxPassword) { throw "Falta el parámetro PfxPassword" }

    $signtool = Resolve-SignTool -Candidate $SigntoolPath
    & $signtool sign /fd SHA256 /f $PfxPath /p $PfxPassword $ExePath
    if ($LASTEXITCODE -ne 0) { throw "La firma falló" }

    & $signtool verify /pa /v $ExePath
    if ($LASTEXITCODE -ne 0) { throw "La verificación de firma falló" }

    Write-Host "Aplicación firmada correctamente" -ForegroundColor Green
    Write-Host (Resolve-Path $ExePath)
}
finally {
    Pop-Location
}
