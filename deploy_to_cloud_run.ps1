#!/usr/bin/env pwsh
# Cloud Run deployment script for SAO backend.

param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $false)][string]$Region = "us-central1",
    [Parameter(Mandatory = $false)][string]$ServiceName = "sao-api",
    [Parameter(Mandatory = $false)][string]$ImageName = "sao-api",
    [Parameter(Mandatory = $false)][string]$ServiceAccountEmail = "",
    [Parameter(Mandatory = $false)][string]$SmokeEmail = "",
    [Parameter(Mandatory = $false)][string]$SmokePassword = "",
    [Parameter(Mandatory = $false)][switch]$DisallowUnauthenticated
)

$ErrorActionPreference = "Stop"

function Assert-LastCommand {
    param([string]$Step)
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $Step"
    }
}

if ($ProjectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$') {
    throw "Invalid ProjectId format: $ProjectId"
}

if ([string]::IsNullOrWhiteSpace($ServiceAccountEmail)) {
    $ServiceAccountEmail = "sao-runner@$ProjectId.iam.gserviceaccount.com"
}

if ([string]::IsNullOrWhiteSpace($SmokeEmail)) {
    $SmokeEmail = $env:SAO_SMOKE_EMAIL
}

if ([string]::IsNullOrWhiteSpace($SmokePassword)) {
    $SmokePassword = $env:SAO_SMOKE_PASSWORD
}

Write-Host "`n🚀 SAO Backend - Cloud Run Deployment" -ForegroundColor Cyan
Write-Host ("=" * 70)
Write-Host "Project: $ProjectId | Region: $Region | Service: $ServiceName" -ForegroundColor White
Write-Host "Service Account: $ServiceAccountEmail" -ForegroundColor White
Write-Host "Mode: Firestore-only strict" -ForegroundColor White
Write-Host ("=" * 70)

Write-Host "`n[1/5] Setting active project..." -ForegroundColor Yellow
gcloud config set project $ProjectId
Assert-LastCommand -Step "set active project"
gcloud auth application-default set-quota-project $ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Could not set ADC quota project. Continuing." -ForegroundColor Yellow
}

Write-Host "`n[2/5] Building container image..." -ForegroundColor Yellow
Push-Location .\backend
gcloud builds submit --tag gcr.io/$ProjectId/$ImageName .
Assert-LastCommand -Step "build image"

Write-Host "`n[3/5] Deploying Cloud Run service..." -ForegroundColor Yellow
if (-not $DisallowUnauthenticated) {
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
        --set-env-vars "DATA_BACKEND=firestore,RUN_STARTUP_MIGRATIONS=false,FIRESTORE_PROJECT_ID=$ProjectId,FIRESTORE_DATABASE=(default),FIRESTORE_READ_EVENTS=true,FIRESTORE_READ_ACTIVITIES=true" `
        --update-secrets "JWT_SECRET=JWT_SECRET:latest,GCS_BUCKET=GCS_BUCKET:latest" `
        --remove-secrets "DATABASE_URL" `
        --clear-cloudsql-instances `
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
        --set-env-vars "DATA_BACKEND=firestore,RUN_STARTUP_MIGRATIONS=false,FIRESTORE_PROJECT_ID=$ProjectId,FIRESTORE_DATABASE=(default),FIRESTORE_READ_EVENTS=true,FIRESTORE_READ_ACTIVITIES=true" `
        --update-secrets "JWT_SECRET=JWT_SECRET:latest,GCS_BUCKET=GCS_BUCKET:latest" `
        --remove-secrets "DATABASE_URL" `
        --clear-cloudsql-instances `
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
.\scripts\smoke_test_prod.ps1 -BaseUrl $serviceUrl -Email $SmokeEmail -LoginPassword $SmokePassword
Assert-LastCommand -Step "smoke test"
Write-Host "✅ Smoke test passed" -ForegroundColor Green

Pop-Location
