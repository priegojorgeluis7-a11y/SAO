param(
    [string]$PythonExe = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if ([string]::IsNullOrWhiteSpace($PythonExe)) {
    $venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"
    if (Test-Path $venvPython) {
        $PythonExe = $venvPython
    }
    else {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($null -ne $pythonCmd) {
            $PythonExe = $pythonCmd.Source
        }
    }
}

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found: $PythonExe"
}

Write-Host "[firestore-smoke] Repo root: $repoRoot"
Write-Host "[firestore-smoke] Python: $PythonExe"

Push-Location $repoRoot
try {
    & $PythonExe -m pytest backend/tests/test_catalog_bundle.py -q -k "firestore_"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $PythonExe -m pytest backend/tests/test_sync.py -q -m integration -k "firestore_sync_"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $PythonExe -m pytest backend/tests/test_auth.py -q -k "firestore_login or firestore_verify_project_access"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $PythonExe -m pytest backend/tests/test_firestore_e2e_flow.py -q -k "firestore_e2e_"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "[firestore-smoke] OK: firestore-only regression smoke suite passed."
}
finally {
    Pop-Location
}
