# 🚀 Guía rápida de despliegue

**Duración:** ~2 horas  
**Complejidad:** media  
**Estado:** lista para ejecutar

---

## 🎯 Antes de empezar

### Revisión de prerrequisitos
```bash
✅ Docker installed
✅ gcloud CLI installed
✅ GCP Project created
✅ Billing enabled
✅ Google Play account active
```

If anything is missing, install it first.

---

## BACKEND DEPLOYMENT (20 min)

### Step 1: Setup Cloud Run

```bash
# 1. Set variables
export PROJECT_ID="your-gcp-project"
export REGION="us-central1"
export SERVICE_NAME="sao-backend"

gcloud config set project $PROJECT_ID

# 2. Create secret
gcloud secrets create SAO_SECRET_KEY --data-file=- << 'EOF'
$(openssl rand -hex 32)
EOF

# 3. Grant Cloud Run access to secrets
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
gcloud secrets add-iam-policy-binding SAO_SECRET_KEY \
  --member=serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
```

### Step 2: Deploy Backend

```bash
cd d:\SAO\backend

# Build & Deploy (one command)
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --platform managed \
  --memory 512Mi \
  --cpu 1 \
  --set-env-vars=DEBUG=False,LOG_LEVEL=INFO \
  --allow-unauthenticated

# Get URL
BACKEND_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format="value(status.url)")

echo "Backend URL: $BACKEND_URL"
```

### Step 3: Verify Backend

```bash
# Test health endpoint
curl $BACKEND_URL/health

# Expected response:
# {"status":"healthy","timestamp":"2026-02-24T...","version":"1.0.0-mock"}
```

**CheckList:**
- [ ] Backend deployed
- [ ] Health check passes
- [ ] URL saved (you'll need it for mobile)

---

## MOBILE APP DEPLOYMENT (30 min)

### Step 1: Update API URL

Edit `lib/data/remote/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = '$BACKEND_URL'; // Use deployed URL
  // ...
}
```

### Step 2: Build Release APK

```bash
cd d:\SAO\frontend_flutter\sao_windows

# Build
flutter build apk --release

# Output: build/app/outputs/flutter-app.apk
```

### Step 3: Upload to Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app (or create new)
3. Go to **Release** → **Create new release**
4. Upload APK from `build/app/outputs/flutter-app.apk`
5. Add release notes
6. **Set rollout to 5%** (don't go 100% yet)
7. Click **Review and Deploy**

**CheckList:**
- [ ] APK uploaded
- [ ] Release created
- [ ] Rollout set to 5%
- [ ] Status: awaiting review

---

## ⏱️ WAIT & MONITOR (30 min)

### Monitor Backend

```bash
# Check logs
gcloud logging read \
  --limit=20 \
  --filter='resource.type="cloud_run_revision" AND resource.label.service_name="sao-backend"'

# Watch in real-time
gcloud logging read --follow
```

### Monitor Mobile

Wait for:
1. Play Store review complete (~30 min)
2. App available in store
3. Download and test on device:
   - Login with test account
   - Load activities
   - Check sync
   - Verify no crashes

---

## 📈 EXPAND ROLLOUT (After 30 min monitoring OK)

### Step 1: Check Status

If everything looks good:
- ✅ No critical errors
- ✅ Users logging in
- ✅ App performing well

### Step 2: Expand to 25%

1. Go to Play Console → Your Release
2. Click **Manage rollout**
3. Change rollout from 5% to 25%
4. **Confirm**

Wait another 30 minutes with monitoring.

### Step 3: Full Rollout (After 1 hour total)

1. Go to Play Console → Your Release
2. Click **Manage rollout**
3. Change rollout from 25% to 100%
4. **Confirm**

Your app is now 🚀 **LIVE FOR ALL USERS**

---

## 🎯 SUCCESS CRITERIA

Your deployment is successful if:

```
✅ Backend responds to requests
✅ Mobile app downloads from Play Store
✅ Users can login
✅ Zero crashes in first 30 min
✅ Error rate < 0.1%
✅ Response time < 2 seconds
✅ Team confirms: "Production Ready"
```

---

## 🆘 If Something Goes Wrong

### Backend Issues

```bash
# Check status
gcloud run services describe $SERVICE_NAME --region $REGION

# View recent deployments
gcloud run revisions list --service=$SERVICE_NAME --region=$REGION

# Rollback to previous (if needed)
gcloud run services update-traffic $SERVICE_NAME \
  --to-revisions=PREVIOUS_REVISION=100 \
  --region=$REGION
```

### Mobile Issues

In Play Console:
1. Go to your release
2. Click **Stop rollout**
3. Previous version remains available
4. Users won't be forced to update

---

## 📊 Daily Monitoring (First Week)

Each day, check:

```bash
# Error rate
gcloud logging read \
  --filter='severity>=ERROR' \
  --format='table(timestamp, jsonPayload.message)'

# Performance
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count"'

# Active users (Play Store)
# Go to Play Console → Statistics → Active Installs
```

---

## 🎉 DEPLOYMENT COMPLETE!

When you see ✅ on all items:
- Backend deployed and healthy
- Mobile app live on Play Store
- Users accessing the system
- Team confirms production ready

**You're officially in PRODUCTION!** 🚀

---

## 💡 Quick Reference Commands

```bash
# Backend URL
gcloud run services describe sao-backend \
  --region=us-central1 \
  --format="value(status.url)"

# View logs
gcloud logging read --limit=50

# Scale backend (if needed)
gcloud run services update sao-backend \
  --max-instances=10 \
  --region=us-central1

# Check deployment
gcloud run services describe sao-backend --region=us-central1
```

---

**Estimated Total Time:** 2 hours (including 1 hour monitoring)

**Next:** Execute Phase 1 (Backend) now!

