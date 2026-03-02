# Load Testing Quick Start

**Status:** 🚀 Ready to Execute  
**Date:** February 24, 2026  

---

## ⚡ Quick Setup (5 Minutes)

### 1. Install Dependencies

```powershell
# PowerShell in workspace root

# Create virtual environment (if not exists)
python -m venv load_testing_env
.\load_testing_env\Scripts\Activate.ps1

# Install load testing tools
pip install -r load_tests/requirements.txt

# Verify installation
locust --version
python -c "import pandas; print('pandas ok')"
```

**Expected Output:**
```
locust 2.15.1
pandas ok
```

### 2. Start Backend Server

```powershell
# Terminal 2: Start the backend

cd backend
python main.py

# Should show:
# INFO:     Uvicorn running on http://127.0.0.1:8000
# INFO:     Application startup complete
```

**Test backend is running:**
```powershell
# Terminal 3: Verify health
curl http://localhost:8000/health

# Should return: {"status":"healthy"}
```

### 3. Run Quick Test (5 minutes)

```powershell
# Terminal 1: Run light load test
cd load_tests

# Quick test (100 users, 5 min)
.\run_all_tests.ps1

# Or run directly
locust -f locust_light_load.py `
  --host=http://localhost:8000 `
  --users=100 `
  --spawn-rate=10 `
  --run-time=5m `
  --headless `
  --csv=results/light_load
```

**Expected Output:**
```
Starting Locust 2.15.1
Spawning 100 users
spawning 10 users/second...
User count: 10
User count: 20
...
User count: 100
Ramping down
[...requests completing...]
Stopping users
Test finished
✅ Light Load Test Completed
```

---

## 📊 Test Scenarios

### Scenario 1: Quick Test (5 minutes)
```powershell
# Light load: 100 users, typical usage
locust -f locust_light_load.py `
  --host=http://localhost:8000 `
  --users=100 `
  --spawn-rate=10 `
  --run-time=5m `
  --headless `
  --csv=results/light_load

# Results: Should see ~95% success, p95 < 500ms
```

**Best for:** Sanity check, quick validation

### Scenario 2: Upload Heavy Load (10 minutes)
```powershell
# Heavy: 500 users uploading files
locust -f locust_heavy_upload.py `
  --host=http://localhost:8000 `
  --users=500 `
  --spawn-rate=25 `
  --run-time=10m `
  --headless `
  --csv=results/heavy_upload

# Results: Should handle 500 concurrent uploads
```

**Best for:** File upload validation, GCS stress test

### Scenario 3: Production-Like (30 minutes)
```powershell
# Realistic: 1000 mixed users
locust -f locust_realistic.py `
  --host=http://localhost:8000 `
  --users=1000 `
  --spawn-rate=50 `
  --run-time=30m `
  --headless `
  --csv=results/realistic_1000

# Results: Production simulation
```

**Best for:** Final validation before deployment

### Scenario 4: Stress Test (20 minutes, requires k6)
```powershell
# Only if k6 installed: choco install k6

k6 run --vus 100 stress_test.js `
  -e BASE_URL=http://localhost:8000

# Ramps from 100 to 2000 users to find breaking point
```

**Best for:** Finding capacity limit

---

## 📈 Run All Tests (Full Suite)

```powershell
# Run complete test suite (35+ minutes)
.\run_all_tests.ps1 -FullSuite

# Or with custom backend URL
.\run_all_tests.ps1 -BackendUrl http://staging-api.com -FullSuite

# Results will be in: load_tests/results/
```

---

## 🎯 Results Analysis

### Automatic Analysis

After tests complete, results are analyzed automatically:

```powershell
# Analyze results from a test run
python analyze_results.py load_tests/results/

# Output shows:
# ✅ Response time percentiles
# ✅ Error rates
# ✅ Pass/Fail verdict
# ✅ Recommendations
```

### Manual CSV Review

Raw results are in CSV format:

```powershell
# View raw results
format-table -AutoSize load_tests/results/light_load_stats.csv

# Or open in Excel:
start load_tests/results/light_load_stats.csv
```

### Key Metrics to Check

| Metric | Target | Pass |
|--------|--------|------|
| Error Rate | < 0.1% | ✅ |
| p95 Response | < 2s | ✅ |
| p99 Response | < 5s | ✅ |
| Throughput | > 500 req/s | ✅ |

---

## 🔧 Troubleshooting

### Problem: ImportError for locust

```powershell
# Solution: Install pandas dependency
pip install pandas==2.0.3
pip install locust==2.15.1 --force-reinstall
```

### Problem: Backend connection refused

```powershell
# Check backend is running
curl http://localhost:8000/health

# If not running:
cd backend
python main.py
```

### Problem: "No such file: locust_light_load.py"

```powershell
# Make sure you're in load_tests directory
cd load_tests

# Or use full path
locust -f load_tests/locust_light_load.py ...
```

### Problem: Test runs very slowly

```powershell
# Reduce user count or duration
locust -f locust_light_load.py `
  --users=50 `
  --run-time=2m `
  ...
```

### Problem: Results show network errors

- Check backend health: `curl http://localhost:8000/health`
- Check test user exists: `curl http://localhost:8000/auth/login -d '{"email":"testuser@test.com"}'`
- Check backend logs for errors

---

## 📊 Expected Results

### Light Load Test (100 users, 5 min)
```
Total Requests: 12,000
Successful: 11,988 (99.9%)
Failed: 12 (0.1%)

Response Times:
  mean: 450ms
  p50: 400ms
  p95: 800ms
  p99: 1500ms

Verdict: ✅ PASS
```

### Heavy Upload Test (500 users, 10 min)
```
Upload Requests: 5,000
Successful: 4,975 (99.5%)
Failed: 25 (0.5%)

Response Times:
  mean: 18s (per upload)
  p95: 28s

Verdict: ✅ PASS
```

### Realistic Workload (1000 users, 30 min)
```
Total Requests: 60,000
Successful: 59,700 (99.5%)
Failed: 300 (0.5%)

Response Times:
  mean: 600ms
  p95: 1800ms
  p99: 3500ms

Verdict: ✅ PASS
```

---

## ✅ Checklist

Before running tests:
- [ ] Backend server running and healthy
- [ ] Load testing tools installed
- [ ] Test results directory exists
- [ ] Test user exists in database
- [ ] Database has test activities

Before declaring success:
- [ ] All tests completed without crashes
- [ ] Error rate < 1%
- [ ] p95 response time < 2 seconds
- [ ] No memory leaks detected
- [ ] Results saved to CSV

---

## 📞 Common Commands

```powershell
# Install dependencies
pip install -r load_tests/requirements.txt

# Run light test (quick)
locust -f load_tests/locust_light_load.py --host=http://localhost:8000 --users=100 --spawn-rate=10 --run-time=5m --headless --csv=load_tests/results/light_load

# Run all tests
.\load_tests\run_all_tests.ps1 -FullSuite

# Analyze results
python load_tests/analyze_results.py load_tests/results/

# View results
format-table -AutoSize load_tests/results/light_load_stats.csv

# Kill hanging Locust process
Stop-Process -Name python -Force
```

---

## 🎯 Next Steps

1. ✅ Install dependencies (5 min)
2. ✅ Start backend server (< 1 min)
3. ✅ Run light test (5 min)
4. ✅ Review results (5 min)
5. 👉 If pass: Run full suite or proceed to production
6. 👉 If fail: Check why and optimize

---

## 📚 Documentation Links

- [PHASE_7_LOAD_TESTING_FRAMEWORK.md](../PHASE_7_LOAD_TESTING_FRAMEWORK.md) - Full framework docs
- [PHASE_7_QA_LOAD_TESTING_PLAN.md](../PHASE_7_QA_LOAD_TESTING_PLAN.md) - Test scenarios and targets
- [PHASE_7_GETTING_STARTED.md](../PHASE_7_GETTING_STARTED.md) - Overall Phase 7 guide

---

**Status:** 🚀 Ready to run tests  
**Last Updated:** February 24, 2026  
**Good luck!** 🎉
