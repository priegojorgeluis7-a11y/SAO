param(
    [string]$ProjectId = "sao-prod-488416",
    [string]$Region = "us-central1",
    [string]$Instance = "sao-postgres-ent",
    [string]$DatabaseUrlSecret = "DATABASE_URL",
    [string]$JwtSecretName = "JWT_SECRET",
    [string]$GcsBucketSecretName = "GCS_BUCKET",
    [int]$ProxyPort = 5432,
    [bool]$RunSeeds = $true,
    [bool]$SkipEffectiveCatalogSeed = $false
)

$ErrorActionPreference = 'Stop'

function Get-RequiredCommand {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Required command '$Name' was not found in PATH"
    }
    return $cmd
}

function Get-CloudSqlProxyPath {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $toolsDir = Join-Path $repoRoot 'tools'
    if (-not (Test-Path $toolsDir)) {
        New-Item -ItemType Directory -Path $toolsDir | Out-Null
    }

    $proxyPath = Join-Path $toolsDir 'cloud-sql-proxy.exe'
    if (-not (Test-Path $proxyPath)) {
        Write-Host '[CLOUD] Downloading cloud-sql-proxy...'
        Invoke-WebRequest -Uri 'https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.3/cloud-sql-proxy.x64.exe' -OutFile $proxyPath
    }
    return $proxyPath
}

function Parse-CloudSqlUrl {
    param([string]$Url)

    $pattern = '^postgresql(?:\+psycopg)?://(?<user>[^:]+):(?<pass>[^@]+)@/(?<db>[^?]+)\?host=/cloudsql/(?<conn>.+)$'
    $match = [regex]::Match($Url, $pattern)
    if (-not $match.Success) {
        throw "DATABASE_URL secret format is not supported by this script"
    }

    return [pscustomobject]@{
        User = $match.Groups['user'].Value
        Password = $match.Groups['pass'].Value
        Database = $match.Groups['db'].Value
        ConnectionName = $match.Groups['conn'].Value
    }
}

function Get-SecretValue {
    param(
        [string]$Project,
        [string]$SecretName
    )

    $value = gcloud secrets versions access latest --secret=$SecretName --project=$Project
    if (-not $value) {
        throw "Secret '$SecretName' returned empty value"
    }
    return $value.Trim()
}

Get-RequiredCommand -Name 'gcloud' | Out-Null

$backendDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pythonExe = 'd:/SAO/.venv/Scripts/python.exe'
if (-not (Test-Path $pythonExe)) {
    throw "Python executable not found at $pythonExe"
}

Write-Host '[CLOUD] Reading secrets from Secret Manager...'
$databaseUrlSecretValue = Get-SecretValue -Project $ProjectId -SecretName $DatabaseUrlSecret
$jwtSecretValue = Get-SecretValue -Project $ProjectId -SecretName $JwtSecretName
$gcsBucketValue = Get-SecretValue -Project $ProjectId -SecretName $GcsBucketSecretName

$parsed = Parse-CloudSqlUrl -Url $databaseUrlSecretValue
$connectionName = if ($parsed.ConnectionName) { $parsed.ConnectionName } else { "$ProjectId`:$Region`:$Instance" }

$proxyPath = Get-CloudSqlProxyPath

$proxyProcess = $null
try {
    Write-Host "[CLOUD] Starting proxy on 127.0.0.1:$ProxyPort for $connectionName ..."
    $proxyProcess = Start-Process -FilePath $proxyPath -ArgumentList @('--port', $ProxyPort, $connectionName) -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2

    if ($proxyProcess.HasExited) {
        throw 'Cloud SQL proxy exited unexpectedly'
    }

    $encodedUser = [Uri]::EscapeDataString($parsed.User)
    $encodedPass = [Uri]::EscapeDataString($parsed.Password)
    $encodedDb = [Uri]::EscapeDataString($parsed.Database)

    $env:DATABASE_URL = "postgresql://$encodedUser`:$encodedPass@127.0.0.1`:$ProxyPort/$encodedDb"
    $env:JWT_SECRET = $jwtSecretValue
    $env:GCS_BUCKET = $gcsBucketValue
    $env:SAO_SKIP_EFFECTIVE_CATALOG_SEED = if ($SkipEffectiveCatalogSeed) { '1' } else { '0' }

    Set-Location $backendDir

    if ($RunSeeds) {
        Write-Host '[CLOUD] Running migrations + seeds...'
        & $pythonExe scripts/run_migrations_and_seed.py
    }
    else {
        Write-Host '[CLOUD] Running migrations only...'
        & $pythonExe -m alembic upgrade head
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Migration command failed with exit code $LASTEXITCODE"
    }

    Write-Host '[CLOUD] Migration flow completed successfully.'
}
finally {
    if ($proxyProcess -and -not $proxyProcess.HasExited) {
        Stop-Process -Id $proxyProcess.Id -Force
    }
}
