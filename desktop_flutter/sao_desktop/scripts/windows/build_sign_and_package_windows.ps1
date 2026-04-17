param(
    [string]$ProjectRoot = ".",
    [string]$PfxPath,
    [string]$PfxPassword,
    [string]$InnoSetupCompiler = "iscc.exe",
    [string]$InstallerScript = "scripts\windows\sao_desktop_internal_installer.iss"
)

$ErrorActionPreference = 'Stop'

function Resolve-Tool {
    param(
        [string]$CommandName,
        [string[]]$FallbackGlobs = @()
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return (Get-Command $CommandName).Source
    }

    foreach ($glob in $FallbackGlobs) {
        $items = Get-ChildItem -Path $glob -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
        if ($items) {
            return $items[0].FullName
        }
    }

    throw "$CommandName not found."
}

Push-Location $ProjectRoot
try {
    $signScript = Join-Path $PWD "scripts\windows\build_and_sign_windows.ps1"
    if (-not (Test-Path $signScript)) {
        throw "Signing script not found: $signScript"
    }

    & $signScript -ProjectRoot $PWD -PfxPath $PfxPath -PfxPassword $PfxPassword
    if ($LASTEXITCODE -ne 0) {
        throw "Signing step failed with exit code $LASTEXITCODE"
    }

    $iscc = Resolve-Tool -CommandName $InnoSetupCompiler -FallbackGlobs @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )

    if (-not (Test-Path $InstallerScript)) {
        throw "Installer script not found: $InstallerScript"
    }

    Write-Host "Creating internal installer..." -ForegroundColor Cyan
    & $iscc $InstallerScript
    if ($LASTEXITCODE -ne 0) {
        throw "Installer build failed with exit code $LASTEXITCODE"
    }

    $installerPath = Join-Path $PWD "build\windows\installer\SAO_Desktop_Internal_Setup.exe"
    if (-not (Test-Path $installerPath)) {
        throw "Installer not generated at expected path: $installerPath"
    }

    Write-Host "Signing installer..." -ForegroundColor Cyan
    & $signScript -ProjectRoot $PWD -PfxPath $PfxPath -PfxPassword $PfxPassword -SkipBuild -ExePath $installerPath

    Write-Host "Internal installer ready:" -ForegroundColor Green
    Write-Host $installerPath
}
finally {
    Pop-Location
}
