param(
    [string]$ProjectRoot = ".",
    [string]$PfxPath,
    [string]$PfxPassword,
    [string]$SigntoolPath = "signtool.exe",
    [switch]$SkipBuild,
    [switch]$VerifyOnly,
    [string]$ExePath = "build\windows\x64\runner\Release\sao_desktop.exe"
)

$ErrorActionPreference = 'Stop'

function Resolve-SignTool {
    param([string]$Candidate)

    if (Get-Command $Candidate -ErrorAction SilentlyContinue) {
        return (Get-Command $Candidate).Source
    }

    $kitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path $kitsRoot) {
        $found = Get-ChildItem -Path $kitsRoot -Recurse -Filter signtool.exe |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }

    throw "signtool.exe was not found. Install Windows SDK Signing Tools first."
}

Push-Location $ProjectRoot
try {
    if (-not $SkipBuild -and -not $VerifyOnly) {
        Write-Host "Building Flutter Windows release..." -ForegroundColor Cyan
        flutter build windows --release
    }

    if (-not (Test-Path $ExePath)) {
        throw "Executable not found at: $ExePath"
    }

    $resolvedSignTool = Resolve-SignTool -Candidate $SigntoolPath
    Write-Host "Using SignTool: $resolvedSignTool" -ForegroundColor DarkGray

    if (-not $VerifyOnly) {
        if (-not $PfxPath) { throw "Provide -PfxPath" }
        if (-not $PfxPassword) { throw "Provide -PfxPassword" }
        if (-not (Test-Path $PfxPath)) { throw "PFX file not found: $PfxPath" }

        Write-Host "Signing executable..." -ForegroundColor Cyan
        & $resolvedSignTool sign /fd SHA256 /f $PfxPath /p $PfxPassword $ExePath
        if ($LASTEXITCODE -ne 0) {
            throw "SignTool returned exit code $LASTEXITCODE"
        }
    }

    Write-Host "Verifying signature..." -ForegroundColor Cyan
    & $resolvedSignTool verify /pa /v $ExePath
    if ($LASTEXITCODE -ne 0) {
        throw "Signature verification failed with exit code $LASTEXITCODE"
    }

    Write-Host "Signed file ready:" -ForegroundColor Green
    Write-Host (Resolve-Path $ExePath)
}
finally {
    Pop-Location
}
