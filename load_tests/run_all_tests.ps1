# Load Testing Master Runner Script (PowerShell)
# Usage: .\run_all_tests.ps1

param(
    [string]$BackendUrl = "http://localhost:8000",
    [int]$Duration = 5,  # minutes for light test
    [switch]$FullSuite = $false,
    [switch]$SkipSetup = $false
)

Write-Host @"
🚀 SAO Load Testing Suite Launcher
==================================
Backend URL: $BackendUrl
Duration: $Duration minutes
Full Suite: $FullSuite
Time: $(Get-Date)
"@ -ForegroundColor Cyan

# Check prerequisites
Write-Host "`n📋 Checking prerequisites..." -ForegroundColor Yellow

$pythonVersion = python --version 2>&1
if (-not $?) {
    Write-Host "❌ Python not found" -ForegroundColor Red
    exit 1
}
Write-Host "✅ $pythonVersion found" -ForegroundColor Green

$locustVersion = locust --version 2>&1
if (-not $?) {
    Write-Host "❌ Locust not installed. Run: pip install -r load_tests/requirements.txt" -ForegroundColor Red
    exit 1
}
Write-Host "✅ $locustVersion found" -ForegroundColor Green

# Create results directory
$resultsDir = "load_tests/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
    Write-Host "✅ Created results directory: $resultsDir" -ForegroundColor Green
}

Write-Host "`n🧪 Test Suite" -ForegroundColor Cyan

# Test 1: Light Load
Write-Host "`n[1/3] LIGHT LOAD TEST (100 users, $Duration minutes)" -ForegroundColor Yellow
Write-Host "Command: locust -f load_tests/locust_light_load.py --host=$BackendUrl --users=100 --spawn-rate=10 --run-time=${Duration}m --headless --csv=$resultsDir/light_load" -ForegroundColor Gray

locust -f load_tests/locust_light_load.py `
    --host=$BackendUrl `
    --users=100 `
    --spawn-rate=10 `
    --run-time="${Duration}m" `
    --headless `
    --csv="$resultsDir/light_load"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Light Load Test PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ Light Load Test FAILED" -ForegroundColor Red
}

if (-not $FullSuite) {
    Write-Host "`n✅ Quick test complete. Results saved to: $resultsDir" -ForegroundColor Green
    Write-Host "Run with -FullSuite flag to run all tests" -ForegroundColor Gray
    
    # Analyze results
    Write-Host "`n📊 Analyzing results..." -ForegroundColor Yellow
    python load_tests/analyze_results.py $resultsDir
    
    exit 0
}

# Test 2: Heavy Upload
Write-Host "`n[2/3] HEAVY UPLOAD TEST (500 users, 5 minutes)" -ForegroundColor Yellow
Write-Host "Command: locust -f load_tests/locust_heavy_upload.py --host=$BackendUrl --users=500 --spawn-rate=25 --run-time=5m --headless --csv=$resultsDir/heavy_upload" -ForegroundColor Gray

locust -f load_tests/locust_heavy_upload.py `
    --host=$BackendUrl `
    --users=500 `
    --spawn-rate=25 `
    --run-time="5m" `
    --headless `
    --csv="$resultsDir/heavy_upload"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Heavy Upload Test PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ Heavy Upload Test FAILED" -ForegroundColor Red
}

# Test 3: Realistic Workload
Write-Host "`n[3/3] REALISTIC MIXED WORKLOAD TEST (1000 users, 5 minutes)" -ForegroundColor Yellow
Write-Host "Command: locust -f load_tests/locust_realistic.py --host=$BackendUrl --users=1000 --spawn-rate=50 --run-time=5m --headless --csv=$resultsDir/realistic_1000" -ForegroundColor Gray

locust -f load_tests/locust_realistic.py `
    --host=$BackendUrl `
    --users=1000 `
    --spawn-rate=50 `
    --run-time="5m" `
    --headless `
    --csv="$resultsDir/realistic_1000"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Realistic Workload Test PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ Realistic Workload Test FAILED" -ForegroundColor Red
}

# Analyze all results
Write-Host "`n📊 Analyzing all results..." -ForegroundColor Yellow
python load_tests/analyze_results.py $resultsDir

Write-Host "`n✅ Full test suite complete!" -ForegroundColor Green
Write-Host "📁 Results saved to: $resultsDir" -ForegroundColor Cyan
Write-Host "`n📈 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review results above"
Write-Host "  2. If all PASS: Ready for deployment"
Write-Host "  3. If any FAIL: Optimize backend and retest"
Write-Host "  4. Document any bottlenecks found"
