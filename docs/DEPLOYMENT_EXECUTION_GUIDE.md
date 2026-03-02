# 🚀 PRODUCTION DEPLOYMENT EXECUTION PLAN

**Status:** Ready to Deploy  
**Date:** February 24, 2026  
**Max Users:** 50 concurrent  
**Approval:** GO ✅

---

## 📋 Phase 1: Pre-Deployment Setup (30 minutos)

### Paso 1.1: Preparar Credenciales GCP

```bash
# 1. Autenticarse en GCP
gcloud auth login

# 2. Configurar proyecto
gcloud config set project YOUR_PROJECT_ID

# 3. Verificar configuración
gcloud config list
```

**Expected Output:**
```
[core]
project = sao-production
```

### Paso 1.2: Crear Secrets en Secret Manager

```bash
# 1. Create SECRET_KEY
echo -n "$(openssl rand -hex 32)" > secret_key.txt
gcloud secrets create SAO_SECRET_KEY --data-file=secret_key.txt

# 2. Create DATABASE_URL
gcloud secrets create DATABASE_URL \
  --data-file=- << 'EOF'
postgresql://user:password@IP:5432/sao_db
EOF

# 3. Listar secrets
gcloud secrets list
```

**Expected Output:**
```
NAME                 CREATED              REPLICATION_POLICY
DATABASE_URL         2026-02-24T...       AUTOMATIC
SAO_SECRET_KEY       2026-02-24T...       AUTOMATIC
```

### Paso 1.3: Preparar Base de Datos

**Opción A: Cloud SQL (Recomendado)**
```bash
# 1. Crear instancia Cloud SQL
gcloud sql instances create sao-postgres \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1

# 2. Crear database
gcloud sql databases create sao_db \
  --instance=sao-postgres

# 3. Crear usuario
gcloud sql users create sao_user \
  --instance=sao-postgres \
  --password=SECURE_PASSWORD

# 4. Obtener connection string
gcloud sql instances describe sao-postgres \
  --format="value(connectionName)"
```

**Opción B: Local PostgreSQL (Para Testing)**
```bash
# Si usas local durante testing
psql postgresql://user:password@localhost/sao_db \
  -c "CREATE DATABASE sao_db;"
```

### Paso 1.4: Configurar GCS para Evidencias

```bash
# 1. Crear bucket
gsutil mb gs://sao-evidences-prod/

# 2. Configurar permisos
gsutil iam ch serviceAccount:sao-backend@PROJECT.iam.gserviceaccount.com:objectAdmin \
  gs://sao-evidences-prod/

# 3. Habilitar CORS
cat > cors.json << 'EOF'
[
  {
    "origin": ["https://sao-mobile.app"],
    "method": ["GET", "POST", "PUT"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
EOF

gsutil cors set cors.json gs://sao-evidences-prod/
```

---

## 📦 Phase 2: Backend Deployment (20 minutos)

### Paso 2.1: Preparar Backend

```bash
cd d:\SAO\backend

# 1. Validar código
python -m py_compile main.py

# 2. Crear .env.prod
cat > .env.prod << 'EOF'
DATABASE_URL=postgresql://...
SECRET_KEY=$(gcloud secrets versions access latest --secret="SAO_SECRET_KEY")
GCS_BUCKET=sao-evidences-prod
LOG_LEVEL=INFO
DEBUG=False
EOF

# 3. Verificar requirements
pip install -r requirements.txt --dry-run
```

### Paso 2.2: Crear Dockerfile (Si usas Cloud Run)

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Run migrations
RUN python -m alembic upgrade head || true

# Start server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Paso 2.3: Build y Deploy a Cloud Run

```bash
# 1. Build imagen
gcloud builds submit --tag gcr.io/PROJECT/sao-backend:v1.0.0

# 2. Deploy a Cloud Run
gcloud run deploy sao-backend \
  --image gcr.io/PROJECT/sao-backend:v1.0.0 \
  --platform managed \
  --region us-central1 \
  --memory 512Mi \
  --cpu 1 \
  --set-env-vars DATABASE_URL=$(gcloud secrets versions access latest --secret="DATABASE_URL"),\
SECRET_KEY=$(gcloud secrets versions access latest --secret="SAO_SECRET_KEY"),\
GCS_BUCKET=sao-evidences-prod,\
LOG_LEVEL=INFO \
  --allow-unauthenticated

# 3. Obtener URL
gcloud run services describe sao-backend --platform managed --region us-central1 \
  --format="value(status.url)"
```

**Expected Output:**
```
https://sao-backend-RANDOM.run.app
```

### Paso 2.4: Validar Backend

```bash
# 1. Health check
BACKEND_URL=$(gcloud run services describe sao-backend \
  --platform managed --region us-central1 \
  --format="value(status.url)")

curl $BACKEND_URL/health

# Expected: {"status":"healthy"}

# 2. Test login
curl -X POST $BACKEND_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"testuser@test.com","password":"password123"}'

# Expected: {"access_token":"...", "token_type":"bearer"}
```

**CheckList:**
- [ ] Health check returns 200
- [ ] Login returns access_token
- [ ] No errors in logs

---

## 📱 Phase 3: Mobile App Deployment (30 minutos)

### Paso 3.1: Configurar URL de Producción

En `lib/data/remote/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = 'https://sao-backend-RANDOM.run.app';
  // Or use environment variable:
  // static const String baseUrl = String.fromEnvironment('API_URL');
}
```

### Paso 3.2: Build Release APK

```bash
cd d:\SAO\frontend_flutter\sao_windows

# 1. Clean build
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build release
flutter build apk --release

# File location: build/app/outputs/flutter-app.apk
```

### Paso 3.3: Firmar APK

```bash
# 1. Crear key store (si no existe)
keytool -genkey -v -keystore sao-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias sao-key

# 2. Configurar firmas en pubspec.yaml o gradle
# [Already configured in Flutter project]

# 3. Verificar firma
jarsigner -verify -verbose build/app/outputs/flutter-app.apk
```

### Paso 3.4: Upload a Play Store

```bash
# 1. Aceptar Google Play Developer Terms
# https://play.google.com/console

# 2. Crear aplicación
# - App name: SAO
# - Category: Business
# - Target countries: Colombia (o tus destinos)

# 3. Upload APK
# - Internal Testing → Upload APK
# - Review y aprobar

# 4. Crear release
# - Create new release → Add APKs
# - Add release notes
# - Set rollout: 5% → 25% → 100%
```

### Paso 3.5: QA Validation (15 min)

**Test Checklist:**
```
[ ] App instala correctamente
[ ] Login funciona con prod backend
[ ] Activities se cargan
[ ] Offline mode funciona
[ ] Sync bidireccional OK
[ ] Upload de evidencias OK
[ ] No crashes en operaciones básicas
[ ] Performance aceptable (< 2s respuesta)
```

---

## 🔍 Phase 4: Monitoring Setup (15 minutos)

### Paso 4.1: Configurar Cloud Logging

```bash
# Logs ya están en Cloud Logging por default
# Ver logs:
gcloud logging read "resource.type=cloud_run_revision AND \
  resource.label.service_name=sao-backend" \
  --limit 50 \
  --format json
```

### Paso 4.2: Crear Alertas

```bash
# 1. Alert para Error Rate > 1%
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="SAO Backend Error Rate" \
  --condition-severity=WARNING \
  --condition-threshold=1.0

# 2. Alert para Response Time > 2s
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="SAO Backend Response Time" \
  --condition-severity=WARNING \
  --condition-threshold=2000
```

### Paso 4.3: Setup Cloud Monitoring Dashboard

```bash
# Crear dashboard
gcloud monitoring dashboards create --config-from-file=- << 'EOF'
{
  "displayName": "SAO Production Dashboard",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Request Rate",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_count\""
                }
              }
            }]
          }
        }
      }
    ]
  }
}
EOF
```

---

## ✅ Phase 5: Go Live Checklist (10 minutos)

### Pre-Live Validation

```bash
# 1. Backend health
BACKEND_URL=$(gcloud run services describe sao-backend \
  --platform managed --region us-central1 \
  --format="value(status.url)")

echo "1. Health check:"
curl -s $BACKEND_URL/health | jq .

# 2. Database connectivity
echo "2. Database status:"
gcloud sql instances describe sao-postgres --format="value(state)"

# 3. GCS connectivity
echo "3. GCS bucket access:"
gsutil ls gs://sao-evidences-prod/

# 4. Monitoring setup
echo "4. Monitoring enabled:"
gcloud monitoring policies list --format="value(displayName)" | grep -i sao
```

### Final Checklist

```
[ ] Backend health check: OK
[ ] Database: CONNECTED
[ ] GCS: ACCESSIBLE
[ ] Monitoring: CONFIGURED
[ ] Mobile app: QA PASSED
[ ] Team approval: CONFIRMED
[ ] Rollback plan: READY

✅ READY FOR GO LIVE
```

---

## 🎬 Phase 6: Go Live! (5 minutos)

### Step 1: Enable Mobile App Release

```bash
# In Google Play Console:
# 1. Internal Testing → Create Release
# 2. Add release notes
# 3. Set rollout: 5%
# 4. Review & Publish

# Expected: Available to 5% of users in ~30 minutes
```

### Step 2: Monitor Metrics

```bash
# Terminal 1: Watch logs
gcloud logging read "resource.type=cloud_run_revision" \
  --limit=10 \
  --follow

# Terminal 2: Check metrics
watch -n 5 '
gcloud monitoring time-series list \
  --filter="metric.type=run.googleapis.com/request_count" \
  --format="table(resource, value)"
'

# Terminal 3: Check errors
watch -n 10 '
gcloud logging read "severity>=ERROR" --limit=5 --format=json
'
```

### Step 3: Expand Rollout (After 30 min monitoring)

```bash
# If all OK → Expand to 25%
gcloud play releases create \
  --rollout-percent=25 \
  # In Play Console

# Monitor another 30 min
```

### Step 4: Full Rollout (After 1 hour total monitoring)

```bash
# If all OK → Full rollout to 100%
gcloud play releases create \
  --rollout-percent=100

# Expected: Available to all users immediately
```

---

## 📊 Phase 7: Post-Deployment Monitoring (24+ hours)

### First Hour Checklist

```
Time: T+15 min
[ ] App installs from Play Store
[ ] Users can login
[ ] Activities load
[ ] 0 critical errors
[ ] Response time < 2s
Decision: Continue or Rollback?

Time: T+30 min
[ ] 5% rollout users: All OK
[ ] Database: Stable
[ ] Error rate: < 0.1%
[ ] CPU/Memory: Normal
Decision: Expand to 25%?

Time: T+60 min
[ ] 25% rollout users: All OK
[ ] Sync working correctly
[ ] No user complaints
[ ] Performance metrics stable
Decision: Full rollout?

Time: T+120 min (2 hours)
[ ] All metrics healthy
[ ] Usage patterns normal
[ ] No critical issues
[ ] Team confirms: PRODUCTION READY ✅
```

### Daily Monitoring (First 7 days)

```
Daily Metrics to Check:
[ ] Error rate (should be < 0.1%)
[ ] Response time (should be < 2s avg)
[ ] Active users (should grow or stabilize)
[ ] API throughput (should be consistent)
[ ] Database performance (queries < 100ms)
[ ] GCS upload success (should be > 99%)
```

---

## 🆘 Rollback Procedure (If Needed)

### Backend Rollback

```bash
# If something goes wrong, rollback to previous version

# 1. List previous versions
gcloud run revisions list \
  --service sao-backend \
  --platform managed \
  --region us-central1

# 2. Route traffic to previous version
gcloud run services update-traffic sao-backend \
  --to-revisions PREVIOUS_REVISION=100 \
  --platform managed \
  --region us-central1

# 3. Verify
curl https://sao-backend-RANDOM.run.app/health
```

### Mobile App Rollback

```bash
# In Google Play Console:
# 1. Edit release
# 2. Stop rollout
# 3. Close/Cancel release
# 4. Previous version remains available

# Users will stay on previous version
```

---

## 📞 Support & Resources

### Logging

```bash
# Recent errors
gcloud logging read "severity>=ERROR" --limit 20

# Search specific endpoint
gcloud logging read "jsonPayload.endpoint=/auth/login" --limit 10

# Stream logs in real-time
gcloud logging read --follow
```

### Metrics

```bash
# Request count
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count"'

# Error rate
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count" AND metric.response_code_class="5xx"'
```

### Troubleshooting

```bash
# If backend is down
gcloud run services describe sao-backend

# Check Cloud SQL connectivity
gcloud sql operations list --instance=sao-postgres

# Check GCS permissions
gsutil iam get gs://sao-evidences-prod/
```

---

## ✨ Summary

**Deployment Steps:**
1. ✅ Pre-deployment (Credentials, DB, Secrets)
2. ✅ Backend deployment (Cloud Run)
3. ✅ Mobile app deployment (Play Store)
4. ✅ Monitoring setup
5. ✅ Go live (5% → 25% → 100%)
6. ✅ Monitor 24+ hours

**Total Time:** ~2 hours + monitoring

**Success Criteria:**
- ✅ Zero critical errors
- ✅ < 0.1% error rate
- ✅ < 2s response time
- ✅ Users can login and use app
- ✅ System stable after 24 hours

---

🚀 **Ready to deploy!**

Execute Phase 1-2 for backend, then Phase 3-6 for mobile.

Mon