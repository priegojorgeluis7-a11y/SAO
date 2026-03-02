# 🔌 Cloud SQL Integration - Resumen Técnico

**Estado:** ✅ Listo para Integración  
**Complejidad:** Baja (Automatizado 90%)  
**Tiempo Estimado:** 30 minutos

---

## 📊 Arquitectura de Conexión

```
┌─────────────────────────────────────────────────────────────┐
│                  MOBILE APP (Flutter)                       │
│                  (WiFi/Cellular)                            │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              CLOUD RUN (FastAPI Backend)                    │
│  • Auto-scaling: 1-100 replicas                             │
│  • Memory: 512Mi                                            │
│  • CPU: 1 vCPU                                              │
└────────────────────┬────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
    INTERNAL VPC SOCKET         │
   (Cloud SQL Auth Proxy)        │ (fallback TCP)
          │                     │
          ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│         CLOUD SQL (PostgreSQL 15)                           │
│  • Instance: sao-db                                         │
│  • Database: sao                                            │
│  • Connection: /cloudsql/{project}:{region}:{instance}      │
│  • Tier: db-g1-small (0.5 vCPU, 1.7GB RAM, 20GB SSD)       │
│  • Backups: Daily @ 3:00 AM                                 │
│  • HA: Regional (multi-zone)                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔑 Strings de Conexión

### Local Development (SQLite)
```
DATABASE_URL=sqlite:///./sao.db
```

### Local with PostgreSQL
```
DATABASE_URL=postgresql://sao_user:password@localhost:5432/sao
```

### Cloud Run + Cloud SQL (via Auth Proxy) ⭐
```
DATABASE_URL=postgresql://sao_user:PASSWORD@/sao?host=/cloudsql/PROJECT_ID:us-central1:sao-db
```

### Cloud Run + Cloud SQL (TCP) - Backup
```
DATABASE_URL=postgresql://sao_user:PASSWORD@INSTANCE_IP:5432/sao
```

---

## 📋 Configuración Requerida

### 1. Environment Variables

| Variable | Valor | Origen |
|----------|-------|--------|
| `DATABASE_URL` | Connection string | Secret Manager |
| `JWT_SECRET` | Random 64 chars | Secret Manager |
| `GCS_BUCKET` | sao-evidences | Secret Manager |
| `CORS_ORIGINS` | Frontend URLs | .env.production |

### 2. Secrets en Secret Manager

```
✅ db-password         → Contraseña de DB
✅ database-url        → Connection string PostgreSQL
✅ jwt-secret          → JWT signing key
```

### 3. IAM Permissions

**Service Account:** `{PROJECT_ID}-compute@appspot.gserviceaccount.com`

Roles requeridos:
- ✅ `roles/cloudsql.client` → Conectar a Cloud SQL
- ✅ `roles/secretmanager.secretAccessor` → Acceder a secrets
- ✅ `roles/storage.objectViewer` → Leer GCS buckets
- ✅ `roles/storage.objectCreator` → Escribir a GCS buckets

---

## 🚀 Guía Rápida de Setup

### Opción 1: Automatizado (Recomendado) ⭐

```powershell
cd d:\SAO

# Paso 1: Setup Cloud SQL (crea instancia + DB + usuario)
.\backend\setup_cloud_sql.ps1 `
    -ProjectId "tu-proyecto-gcp" `
    -DBPassword "ContraseñaFuerte123!@#" `
    -Region "us-central1"

# Paso 2: Deploy a Cloud Run (build + deploy + test)
.\deploy_to_cloud_run.ps1 `
    -ProjectId "tu-proyecto-gcp" `
    -DBPassword "ContraseñaFuerte123!@#" `
    -JwtSecret "jwt-secret-64-caracteres-aleatorios"
```

**Tiempo total:** ~45 minutos (20 min setup + 25 min build)

### Opción 2: Manual

1. Ver [CLOUD_SQL_INTEGRATION_GUIDE.md](CLOUD_SQL_INTEGRATION_GUIDE.md)
2. Ejecutar cada paso por separado
3. Validar conexión en cada fase

---

## ✅ Puntos de Verificación

### ✓ Cloud SQL Creada
```powershell
gcloud sql instances describe sao-db --region=us-central1
```

### ✓ Base de Datos y Usuario
```powershell
gcloud sql connect sao-db --user=sao_user
# En la terminal: \l (listar DBs) y \du (listar usuarios)
```

### ✓ Backend Deployado
```powershell
gcloud run services describe sao-backend --region=us-central1
```

### ✓ Conexión Funciona
```powershell
# Backend URL
$URL = gcloud run services describe sao-backend `
  --platform managed --region us-central1 `
  --format "value(status.url)"

# Test health check
curl -X GET "$URL/health"

# Debería responder:
# {"status":"healthy","database":"connected"}
```

### ✓ Endpoints Respond
```powershell
# Login endpoint
curl -X POST "$URL/api/v1/auth/login" `
  -H "Content-Type: application/json" `
  -d '{"email":"test@example.com","password":"pass"}'
```

---

## 🔍 Monitoreo

### Logs en Tiempo Real
```powershell
gcloud run logs read sao-backend --region=us-central1 --follow
```

### Conexión a Base de Datos
```powershell
gcloud sql connect sao-db --user=sao_user

# SQL queries
\dt                    # List tables
SELECT COUNT(*) FROM activities;  # Count activities
\q                     # Quit
```

### Métricas Cloud Run
```powershell
# CPU usage
gcloud monitoring time-series list --filter \
  "resource.type=cloud_run_revision AND metric.type=run.googleapis.com/request_count"
```

---

## 🐛 Troubleshooting Rápido

### Error: "Cannot connect to database"

```powershell
# ✓ Verificar Cloud SQL está en verde
gcloud sql instances describe sao-db

# ✓ Verificar IAM permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:*@appspot.gserviceaccount.com"

# ✓ Verificar Cloud Run tiene acceso a Cloud SQL
gcloud run services describe sao-backend --region=us-central1 | grep cloudsql

# ✓ Ver logs del backend
gcloud run logs read sao-backend --region=us-central1 --limit=50
```

### Error: "Authentication failed"

```powershell
# Recrear usuario
gcloud sql users create sao_user --instance=sao-db --password=NEW_PASSWORD

# Actualizar secrets
echo "NEW_PASSWORD" | gcloud secrets versions add db-password --data-file=-
```

### Error: "Out of memory" en Cloud Run

```powershell
# Aumentar memoria
gcloud run services update sao-backend \
  --memory=1Gi \
  --cpu=2
```

---

## 💰 Costos Estimados (USD/mes)

```
Cloud SQL (db-g1-small):           $25-35
  • Compute: ~$20
  • Storage (20GB): ~$5
  • Backups: Included

Cloud Run (1K req/día, 100 users):  $5-15
  • Per-request: $0.00000400
  • Memory: $0.0000100/GB-second
  • With 50 users: ~$0

Cloud Storage (5GB evidences):      $0.12
  • Storage: $0.020/GB
  • Requests: ~$0.004

TOTAL:                              ~$30-50/mes
```

---

## 📚 Documentos Relacionados

- [CLOUD_SQL_INTEGRATION_GUIDE.md](CLOUD_SQL_INTEGRATION_GUIDE.md) - Guía completa
- [DEPLOYMENT_QUICKSTART.md](DEPLOYMENT_QUICKSTART.md) - Deployment rápido
- [PRODUCTION_READINESS_CHECKLIST.md](PRODUCTION_READINESS_CHECKLIST.md) - Checklist final

---

## 🎯 Próximos Pasos

### Today (30 min)
1. ✅ Setup Cloud SQL
2. ✅ Deploy Backend a Cloud Run
3. ✅ Test endpoints

### This Week
4. ⏳ Deploy Mobile App a Play Store
5. ⏳ Configure monitoring alerts
6. ⏳ Setup backup retention

### Before Launch
7. ⏳ Load test con BD real
8. ⏳ Setup disaster recovery
9. ⏳ Configure CDN para assets

---

## ✨ Ventajas de Cloud SQL + Cloud Run

```
✅ Autoreparación automática
✅ Backups automáticos diarios
✅ Auto-scaling de replicas (1-100)
✅ Point-in-time recovery (35 días)
✅ SSL/TLS encryption en tránsito
✅ Network encryption en reposo
✅ Monitoring integrado
✅ Low maintenance (managed service)
✅ Fácil migración a versiones nuevas
✅ Failover automático (HA Regional)
```

---

## 🚀 Listo para Ejecutar

¿Qué necesitas para empezar?

1. **PROJECT_ID de GCP** (ej: `sao-prod-2026`)
2. **Contraseña DB fuerte** (ej: `Xy9$mK2@pL4#nQ7!`)
3. **JWT_SECRET** (generar: `python -c "import secrets; print(secrets.token_hex(32))"`)

Con eso, ejecuto TODO automáticamente. 🎉

