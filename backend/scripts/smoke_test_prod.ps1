#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory = $false)][string]$BaseUrl = "https://sao-api-97150883570.us-central1.run.app",
    [Parameter(Mandatory = $false)][string]$Email,
    [Parameter(Mandatory = $false)][SecureString]$LoginSecret,
    [Parameter(Mandatory = $false)][string]$LoginPassword,
    [Parameter(Mandatory = $false)][int]$HealthRetries = 6,
    [Parameter(Mandatory = $false)][int]$HealthRetryDelaySec = 5
)

$ErrorActionPreference = "Stop"

function Stop-SmokeTest {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
    exit 1
}

function Get-HttpStatusCode {
    param([System.Exception]$Exception)
    if ($null -eq $Exception) { return $null }
    if ($null -ne $Exception.Response -and $null -ne $Exception.Response.StatusCode) {
        return [int]$Exception.Response.StatusCode
    }
    return $null
}

Write-Host "\n🚦 SAO Production Smoke Test" -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($Email)) {
    $Email = $env:SAO_SMOKE_EMAIL
}

if ($null -eq $LoginSecret -and [string]::IsNullOrWhiteSpace($LoginPassword)) {
    $LoginPassword = $env:SAO_SMOKE_PASSWORD
}

if ([string]::IsNullOrWhiteSpace($Email)) {
    Stop-SmokeTest "Missing smoke credentials: provide -Email or SAO_SMOKE_EMAIL"
}

if ($null -eq $LoginSecret -and [string]::IsNullOrWhiteSpace($LoginPassword)) {
    Stop-SmokeTest "Missing smoke credentials: provide -LoginPassword/-LoginSecret or SAO_SMOKE_PASSWORD"
}

Write-Host "BaseUrl: $BaseUrl"
Write-Host "User: $Email"

$healthUrl = "$BaseUrl/health"
$loginUrl = "$BaseUrl/api/v1/auth/login"
$activitiesUrl = "$BaseUrl/api/v1/activities"

Write-Host "\n[1/3] Getting Cloud Run identity token..." -ForegroundColor Yellow
$idToken = gcloud auth print-identity-token
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($idToken)) {
    Stop-SmokeTest "Could not get identity token from gcloud"
}

Write-Host "[2/3] Checking /health..." -ForegroundColor Yellow
$health = $null
$healthAttempt = 0
while ($healthAttempt -lt $HealthRetries) {
    $healthAttempt += 1
    try {
        $health = Invoke-RestMethod -Method Get -Uri $healthUrl -Headers @{ Authorization = "Bearer $idToken" }
        break
    } catch {
        $statusCode = Get-HttpStatusCode -Exception $_.Exception
        if (($statusCode -eq 429) -and ($healthAttempt -lt $HealthRetries)) {
            Write-Host "Health returned 429, retrying in $HealthRetryDelaySec s ($healthAttempt/$HealthRetries)..." -ForegroundColor Yellow
            Start-Sleep -Seconds $HealthRetryDelaySec
            continue
        }
        Stop-SmokeTest "Health check failed: $($_.Exception.Message)"
    }
}

if ($null -eq $health) {
    Stop-SmokeTest "Health check failed after $HealthRetries attempts"
}

if (($health.status -ne "ok") -and ($health.status -ne "healthy")) {
    Stop-SmokeTest "Unexpected health status: $($health.status)"
}
Write-Host "✅ Health OK" -ForegroundColor Green

Write-Host "[3/3] Login + activities..." -ForegroundColor Yellow
$plainSecret = $LoginPassword
if ($null -ne $LoginSecret) {
    $plainSecret = [System.Net.NetworkCredential]::new("", $LoginSecret).Password
}
$loginBody = @{ email = $Email; password = $plainSecret } | ConvertTo-Json

try {
    $login = Invoke-RestMethod -Method Post -Uri $loginUrl -Headers @{ Authorization = "Bearer $idToken"; "Content-Type" = "application/json" } -Body $loginBody
} catch {
    Stop-SmokeTest "Login failed: $($_.Exception.Message)"
}

if (-not $login.access_token) {
    Stop-SmokeTest "Login did not return access_token"
}

$apiToken = $login.access_token

try {
    $activities = Invoke-RestMethod -Method Get -Uri $activitiesUrl -Headers @{ Authorization = "Bearer $apiToken"; "X-Serverless-Authorization" = "Bearer $idToken" }
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
