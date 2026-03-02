#!/usr/bin/env pwsh
# Cloud Run deployment script for SAO backend.

param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$DbSecret,
    [Parameter(Mandatory = $true)][string]$JwtTokenSecret,
    [Parameter(Mandatory = $false)][string]$Region = "us-central1",
    [Parameter(Mandatory = $false)][string]$ServiceName = "sao-api",
    [Parameter(Mandatory = $false)][string]$ImageName = "sao-api",
    [Parameter(Mandatory = $false)][string]$DbName = "sao",
    [Parameter(Mandatory = $false)][string]$DbUser = "sao_user",
    [Parameter(Mandatory = $false)][string]$InstanceName = "sao-postgres-ent",
    [Parameter(Mandatory = $false)][string]$ServiceAccountEmail = "",
    [Parameter(Mandatory = $false)][switch]$SkipSqlSetup,
    [Parameter(Mandatory = $false)][switch]$AllowUnauthenticated
)

$ErrorActionPreference = "Stop"

function Assert-LastCommand {
    param([string]$Step)
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $Step"
    }
}

function Assert-NotEmpty {
    param([string]$Value, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name cannot be empty"
    }
}

if ($ProjectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$') {
    throw "Invalid ProjectId format: $ProjectId"
}

Assert-NotEmpty -Value $DbSecret -Name "DbSecret"
Assert-NotEmpty -Value $JwtTokenSecret -Name "JwtTokenSecret"

if ([string]::IsNullOrWhiteSpace($ServiceAccountEmail)) {
    $ServiceAccountEmail = "sao-runner@$ProjectId.iam.gserviceaccount.com"
}

$InstanceConnectionName = "$ProjectId`:$Region`:$InstanceName"
$DBConnectionString = "postgresql://${DbUser}:${DbSecret}@/${DbName}?host=/cloudsql/${InstanceConnectionName}"

Write-Host "`n🚀 SAO Backend - Cloud Run Deployment" -ForegroundColor Cyan
Write-Host ("=" * 70)
Write-Host "Project: $ProjectId | Region: $Region | Service: $ServiceName" -ForegroundColor White
Write-Host "Service Account: $ServiceAccountEmail" -ForegroundColor White
Write-Host "Cloud SQL: $InstanceConnectionName" -ForegroundColor White
Write-Host ("=" * 70)

Write-Host "`n[0/4] Setting active project..." -ForegroundColor Yellow
gcloud config set project $ProjectId
Assert-LastCommand -Step "set active project"
gcloud auth application-default set-quota-project $ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Could not set ADC quota project. Continuing." -ForegroundColor Yellow
}

if (-not $SkipSqlSetup) {
    Write-Host "`n[1/4] Ensuring Cloud SQL instance exists..." -ForegroundColor Yellow
    gcloud sql instances describe $InstanceName --project $ProjectId 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Creating Cloud SQL instance $InstanceName..." -ForegroundColor Yellow
        gcloud sql instances create $InstanceName `
            --database-version=POSTGRES_15 `
            --tier=db-g1-small `
            --region=$Region `
            --storage-type=SSD `
            --storage-size=20GB `
            --availability-type=REGIONAL `
            --backup-start-time=03:00 `
            --quiet
        Assert-LastCommand -Step "create Cloud SQL instance"
        Write-Host "✅ Cloud SQL instance created" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Cloud SQL instance exists, skipping create" -ForegroundColor Green
    }
}
else {
    Write-Host "`n[1/4] Skipping Cloud SQL setup (existing infrastructure mode)." -ForegroundColor Green
}

Write-Host "`n[2/5] Building container image..." -ForegroundColor Yellow
Push-Location .\backend
gcloud builds submit --tag gcr.io/$ProjectId/$ImageName .
Assert-LastCommand -Step "build image"

Write-Host "`n[3/5] Deploying Cloud Run service..." -ForegroundColor Yellow
if ($AllowUnauthenticated) {
    gcloud run deploy $ServiceName `
        --image gcr.io/$ProjectId/$ImageName `
        --region $Region `
        --service-account $ServiceAccountEmail `
        --cpu 1 `
        --memory 512Mi `
        --min-instances 1 `
        --max-instances 10 `
        --timeout 300 `
        --concurrency 80 `
        --add-cloudsql-instances $InstanceConnectionName `
        --set-secrets "DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest,GCS_BUCKET=GCS_BUCKET:latest" `
        --allow-unauthenticated
}
else {
    gcloud run deploy $ServiceName `
        --image gcr.io/$ProjectId/$ImageName `
        --region $Region `
        --service-account $ServiceAccountEmail `
        --cpu 1 `
        --memory 512Mi `
        --min-instances 1 `
        --max-instances 10 `
        --timeout 300 `
        --concurrency 80 `
        --add-cloudsql-instances $InstanceConnectionName `
        --set-secrets "DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest,GCS_BUCKET=GCS_BUCKET:latest" `
        --no-allow-unauthenticated
}
Assert-LastCommand -Step "deploy Cloud Run"

Write-Host "`n[4/5] Verifying deployed service..." -ForegroundColor Yellow
$serviceUrl = gcloud run services describe $ServiceName --region $Region --format "value(status.url)"
Assert-LastCommand -Step "describe Cloud Run service"

Write-Host "✅ Deployment complete" -ForegroundColor Green
Write-Host "Service URL: $serviceUrl" -ForegroundColor Cyan

Write-Host "`nRecent logs:" -ForegroundColor White
gcloud run services logs read $ServiceName --region $Region --limit 20

Write-Host "`n[5/5] Running smoke test..." -ForegroundColor Yellow
.\scripts\smoke_test_prod.ps1 -BaseUrl $serviceUrl
Assert-LastCommand -Step "smoke test"
Write-Host "✅ Smoke test passed" -ForegroundColor Green

Pop-Location
