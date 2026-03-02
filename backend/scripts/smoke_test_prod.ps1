#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $false)][string]$BaseUrl = "https://sao-api-97150883570.us-central1.run.app",
    [Parameter(Mandatory = $false)][string]$Email = "testuser@test.com",
    [Parameter(Mandatory = $false)][SecureString]$LoginSecret
)

$ErrorActionPreference = "Stop"

function Stop-SmokeTest {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
    exit 1
}

Write-Host "\n🚦 SAO Production Smoke Test" -ForegroundColor Cyan
Write-Host "BaseUrl: $BaseUrl"
Write-Host "User: $Email"

Write-Host "\n[1/3] Getting Cloud Run identity token..." -ForegroundColor Yellow
$idToken = gcloud auth print-identity-token
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($idToken)) {
    Stop-SmokeTest "Could not get identity token from gcloud"
}

Write-Host "[2/3] Checking /health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/health" -Headers @{ Authorization = "Bearer $idToken" }
} catch {
    Stop-SmokeTest "Health check failed: $($_.Exception.Message)"
}

if ($health.status -ne "ok") {
    Stop-SmokeTest "Health status is not ok"
}
Write-Host "✅ Health OK" -ForegroundColor Green

Write-Host "[3/3] Login + activities..." -ForegroundColor Yellow
$plainSecret = "password123"
if ($null -ne $LoginSecret) {
    $plainSecret = [System.Net.NetworkCredential]::new("", $LoginSecret).Password
}
$loginBody = @{ email = $Email; password = $plainSecret } | ConvertTo-Json

try {
    $login = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/login" -Headers @{ Authorization = "Bearer $idToken"; "Content-Type" = "application/json" } -Body $loginBody
} catch {
    Stop-SmokeTest "Login failed: $($_.Exception.Message)"
}

if (-not $login.access_token) {
    Stop-SmokeTest "Login did not return access_token"
}

$apiToken = $login.access_token

try {
    $activities = Invoke-RestMethod -Method Get -Uri "$BaseUrl/activities" -Headers @{ Authorization = "Bearer $apiToken"; "X-Serverless-Authorization" = "Bearer $idToken" }
} catch {
    Stop-SmokeTest "Activities request failed: $($_.Exception.Message)"
}

$count = 0
if ($activities -is [System.Array]) {
    $count = $activities.Count
}

Write-Host "✅ Login OK" -ForegroundColor Green
Write-Host "✅ Activities OK (count=$count)" -ForegroundColor Green

Write-Host "\n🎉 Smoke test passed" -ForegroundColor Green
