# ☁️ Cloud SQL Integration Guide - SAO Backend

**Fecha:** 24 Febrero 2026  
**Estado:** 🚀 Ready to Deploy  
**Tiempo Estimado:** 30 minutos

---

## 📋 Índice

1. [Arquitectura](#arquitectura)
2. [Paso 1: Crear Instancia Cloud SQL](#paso-1-crear-instancia-cloud-sql)
3. [Paso 2: Configurar Credenciales](#paso-2-configurar-credenciales)
4. [Paso 3: Actualizar Backend](#paso-3-actualizar-backend)
5. [Paso 4: Desplegar a Cloud Run](#paso-4-desplegar-a-cloud-run)
6. [Paso 5: Verificar Conexión](#paso-5-verificar-conexión)
7. [Monitoreo](#monitoreo)
8. [Troubleshooting](#troubleshooting)

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────┐
│         Flutter Mobile App                  │
│        (Wi-Fi/Cellular)                     │
└──────────────────┬──────────────────────────┘
                   │
                   │ HTTPS
                   ▼
┌─────────────────────────────────────────────┐
│      Google Cloud Run                       │
│   (SAO Backend FastAPI)                     │
│   - Port: 8080                              │
│   - Replicas: 1-100 (auto-scale)            │
└──────────────────┬──────────────────────────┘
                   │
                   │ Cloud SQL Auth Proxy
                   │ (Internal VPC socket)
                   ▼
┌─────────────────────────────────────────────┐
│      Cloud SQL (PostgreSQL)                 │
│   - Instance: sao-db                        │
│   - Database: sao                           │
│   - Public IP: xxx.xxx.xxx.xxx              │
│   - Size: db-g1-small (0.5 vCPU, 1.7 GB)   │
└─────────────────────────────────────────────┘
```

---

## 🔧 PASO 1: Crear Instancia Cloud SQL

### 1.1 Autenticar en GCP

```powershell
# Login en Google Cloud
gcloud auth login
gcloud auth application-default login

# Set Project ID
$PROJECT_ID = "tu-proyecto-gcp"
gcloud config set project $PROJECT_ID
```

### 1.2 Crear Instancia PostgreSQL

```powershell
# Variables
$INSTANCE_NAME = "sao-db"
$REGION = "us-central1"
$PASSWORD = "GeneraUnaContraseñaFuerte123!@#"  # Cambiar esto

# Crear instancia
gcloud sql instances create $INSTANCE_NAME `
  --database-version=POSTGRES_15 `
  --tier=db-g1-small `
  --region=$REGION `
  --storage-type=PD_SSD `
  --storage-size=20GB `
  --availability-type=REGIONAL `
  --backup-start-time=03:00 `
  --instances-state-zone=$REGION

# Obtener IP pública
$INSTANCE_IP = gcloud sql instances describe $INSTANCE_NAME `
  --format="value(ipAddresses[0].ipAddress)" `
  --region=$REGION

Write-Host "✅ Instancia creada. IP Pública: $INSTANCE_IP"
```

### 1.3 Crear Usuario y Base de Datos

```powershell
# Cambiar password de usuario postgres
gcloud sql users set-password postgres `
  --instance=$INSTANCE_NAME `
  --password=$PASSWORD

# Crear usuario sao_user
gcloud sql users create sao_user `
  --instance=$INSTANCE_NAME `
  --password=$PASSWORD

# Conectar y crear DB
gcloud sql connect $INSTANCE_NAME `
  --user=postgres

# En la terminal SQL:
# CREATE DATABASE sao;
# GRANT ALL PRIVILEGES ON DATABASE sao TO sao_user;
# \q
```

**O usar psql directamente:**

```powershell
# Instalar psql si no está
# choco install postgresql

# Conectar
$INSTANCE_IP = "tu.ip.publica.aqui"
psql -h $INSTANCE_IP -U postgres -d postgres

# SQL commands:
# postgres=# CREATE DATABASE sao;
# postgres=# CREATE USER sao_user WITH PASSWORD 'password';
# postgres=# GRANT ALL PRIVILEGES ON DATABASE sao TO sao_user;
# postgres=# \q
```

---

## 🔐 PASO 2: Configurar Credenciales

### 2.1 Crear Secret en Secret Manager

```powershell
$DB_PASSWORD = "tu_contraseña_aqui"
$INSTANCE_NAME = "sao-db"
$REGION = "us-central1"
$PROJECT_ID = "tu-proyecto"

# Crear secret para DB password
$DB_PASSWORD | gcloud secrets create db-password `
  --replication-policy="automatic"

# Crear secret para connection string
$CONNECTION_STRING = "postgresql://sao_user:$DB_PASSWORD@sao-db:5432/sao"
$CONNECTION_STRING | gcloud secrets create database-url `
  --replication-policy="automatic"
```

### 2.2 Otorgar Permisos a Cloud Run

```powershell
# Obtener service account de Cloud Run
$SA_EMAIL = "$(gcloud config get-value project)-compute@appspot.gserviceaccount.com"

# Dar acceso a secrets
gcloud secrets add-iam-policy-binding db-password `
  --member=serviceAccount:$SA_EMAIL `
  --role=roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding database-url `
  --member=serviceAccount:$SA_EMAIL `
  --role=roles/secretmanager.secretAccessor

# Dar acceso a Cloud SQL
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member=serviceAccount:$SA_EMAIL `
  --role=roles/cloudsql.client
```

---

## 📝 PASO 3: Actualizar Backend

### 3.1 Actualizar .env para Local Development

**Archivo: `d:\SAO\backend\.env`**

```dotenv
# PostgreSQL en desarrollo local
DATABASE_URL=postgresql://sao_user:password@localhost:5432/sao
# O para Cloud SQL Auth Proxy local:
DATABASE_URL=postgresql://sao_user:password@/sao?host=/cloudsql/PROJECT_ID/us-central1/sao-db

JWT_SECRET=dev-secret-key-change-in-production
CORS_ORIGINS=http://localhost:8000,http://localhost:3000
GCS_BUCKET=tu-bucket-gcs
```

### 3.2 Crear .env.production para Cloud Run

**Archivo: `d:\SAO\backend\.env.production`**

```dotenv
# Cloud SQL via Auth Proxy
DATABASE_URL=postgresql://sao_user:PASSWORD@/sao?host=/cloudsql/PROJECT_ID/REGION/INSTANCE_NAME

JWT_SECRET=tu-jwt-secret-cambiar-en-produccion
CORS_ORIGINS=https://tu-app.vercel.app,https://play-store-link.apk
GCS_BUCKET=sao-evidences-prod
```

### 3.3 Instalar Dependencia PostgreSQL

```powershell
# En d:\SAO\backend
pip install psycopg2-binary

# O agregar a requirements.txt
echo "psycopg2-binary==2.9.9" >> requirements.txt
pip install -r requirements.txt
```

### 3.4 Actualizar requirements.txt

```powershell
cd d:\SAO\backend
cat requirements.txt | Select-String "psycopg2" 

# Si no está, agregar:
pip install psycopg2-binary
pip freeze | findstr "psycopg2" >> requirements.txt
```

---

## 🚀 PASO 4: Desplegar a Cloud Run

### 4.1 Preparar Dockerfile Mejorado

**Crear: `d:\SAO\backend\Dockerfile.cloudsql`**

```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup appuser

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy app
COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE $PORT

# Run migration and start
CMD ["/bin/sh", "-c", "alembic upgrade head && uvicorn main:app --host 0.0.0.0 --port 8080"]
```

### 4.2 Build y Deploy a Cloud Run

```powershell
$PROJECT_ID = "tu-proyecto"
$SERVICE_NAME = "sao-backend"
$REGION = "us-central1"
$INSTANCE_CONNECTION_NAME = "$PROJECT_ID:us-central1:sao-db"

# Build image
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME .

# Deploy con Cloud SQL Auth Proxy
gcloud run deploy $SERVICE_NAME `
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME `
  --platform managed `
  --region $REGION `
  --memory 512Mi `
  --cpu 1 `
  --timeout 3600s `
  --set-env-vars "DATABASE_URL=postgresql://sao_user:PASSWORD@/sao?host=/cloudsql/$INSTANCE_CONNECTION_NAME" `
  --set-env-vars "JWT_SECRET=tu-jwt-secret" `
  --set-env-vars "GCS_BUCKET=sao-evidences" `
  --add-cloudsql-instances $INSTANCE_CONNECTION_NAME `
  --service-account=$PROJECT_ID-compute@appspot.gserviceaccount.com `
  --allow-unauthenticated
```

### 4.3 Verificar Deployment

```powershell
# Ver logs
gcloud run logs read $SERVICE_NAME --region=$REGION --limit=100 --follow

# Ver servicio
gcloud run services describe $SERVICE_NAME --region=$REGION
```

---

## ✅ PASO 5: Verificar Conexión

### 5.1 Test de Conectividad

```powershell
# URL del servicio
$SERVICE_URL = gcloud run services describe sao-backend `
  --platform managed `
  --region us-central1 `
  --format "value(status.url)"

Write-Host "Service URL: $SERVICE_URL"

# Test health check
curl -X GET "$SERVICE_URL/health"

# Debería responder:
# {"status":"healthy","database":"connected"}
```

### 5.2 Test de Endpoints

```powershell
# Login
curl -X POST "$SERVICE_URL/api/v1/auth/login" `
  -H "Content-Type: application/json" `
  -d '{
    "email":"testuser@test.com",
    "password":"password123"
  }'

# Get Activities
curl -X GET "$SERVICE_URL/api/v1/activities" `
  -H "Authorization: Bearer TOKEN_AQUI"
```

---

## 📊 Monitoreo

### Logs en Cloud Logging

```powershell
# Ver todos los logs
gcloud run logs read sao-backend --region=us-central1 --limit=50

# Ver solo errores
gcloud run logs read sao-backend --region=us-central1 --filter="severity=ERROR"

# Ver en tiempo real
gcloud run logs read sao-backend --region=us-central1 --follow
```

### Métricas en Cloud Monitoring

```powershell
# Crear dashboard
gcloud monitoring metrics-descriptors list | grep run

# Ver CPU usage
gcloud monitoring time-series list \
  --filter="resource.type=cloud_run_revision AND metric.type=run.googleapis.com/request_count"
```

### Alertas

```powershell
# Crear alerta de high CPU
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="SAO Backend High CPU" \
  --condition-display-name="CPU > 80%" \
  --condition-threshold-value=80 \
  --condition-threshold-filter="resource.type=cloud_run_revision"
```

---

## 🔧 Troubleshooting

### Problema: "Cannot connect to database"

**Solución:**
```powershell
# Verificar variables de entorno
gcloud run services describe sao-backend --region=us-central1 | grep DATABASE

# Verificar Cloud SQL Auth Proxy está corriendo
gcloud run logs read sao-backend --region=us-central1 --limit=50 | grep -i "cloudsql"

# Reconectar Cloud Run a Cloud SQL
gcloud run services update sao-backend `
  --add-cloudsql-instances PROJECT_ID:us-central1:sao-db
```

### Problema: "Authentication failed"

```powershell
# Verificar permisos de IAM
gcloud projects get-iam-policy $PROJECT_ID `
  --flatten="bindings[].members" `
  --filter="bindings.members:serviceAccount:*@appspot.gserviceaccount.com"

# Dar permisos
$SA_EMAIL = "$(gcloud config get-value project)-compute@appspot.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member=serviceAccount:$SA_EMAIL `
  --role=roles/cloudsql.client
```

### Problema: "Migration timeout"

```powershell
# Aumentar timeout en deployment
--timeout=3600s

# O ejecutar migraciones manualmente
gcloud cloud-shell ssh -- "migration command"
```

### Problema: "Out of memory"

```powershell
# Aumentar memoria
gcloud run services update sao-backend `
  --memory=1Gi `
  --cpu=2
```

---

## 🔄 Comandos Rápidos

```powershell
# Deploy automático
./deploy.ps1

# Ver estado
gcloud run services describe sao-backend --region=us-central1

# Ver logs
gcloud run logs read sao-backend --region=us-central1 --follow

# Conectar a DB
gcloud sql connect sao-db --user=sao_user

# Rollback
gcloud run deploy sao-backend --image=gcr.io/$PROJECT_ID/sao-backend:previous

# Delete
gcloud run services delete sao-backend --region=us-central1
```

---

## 📋 Checklist Final

- [ ] Instancia Cloud SQL creada
- [ ] Usuario sao_user creado
- [ ] Base de datos sao creada
- [ ] Secrets en Secret Manager
- [ ] Permisos de IAM configurados
- [ ] requirements.txt actualizado (psycopg2)
- [ ] Dockerfile.cloudsql creado
- [ ] Backend deployado a Cloud Run
- [ ] Test de conectividad exitoso
- [ ] Health check respondiendo
- [ ] Endpoints funcionando
- [ ] Logs en Cloud Logging visible
- [ ] Alertas configuradas
- [ ] Backups automáticos habilitados

---

## 💰 Costos Estimados (USD/mes)

```
Cloud SQL (db-g1-small):        ~$20-30
Cloud Run (1-10 replicas):      ~$5-20
Cloud Storage (5GB evidencias): ~$0.12
Total:                          ~$25-50
```

---

## 📚 Documentos Relacionados

- [DEPLOYMENT_QUICKSTART.md](DEPLOYMENT_QUICKSTART.md)
- [DEPLOYMENT_EXECUTION_GUIDE.md](DEPLOYMENT_EXECUTION_GUIDE.md)
- [PRODUCTION_READINESS_CHECKLIST.md](PRODUCTION_READINESS_CHECKLIST.md)

---

## ✅ Listo para Iniciar

¿Quieres ejecutar ahora? Responde con los datos:

1. **PROJECT_ID de GCP?** (ej: `sao-2026`)
2. **Region?** (ej: `us-central1`)
3. **Contraseña para DB?** (generar algo seguro)
4. **JWT_SECRET?** (generar random 64 chars)

Luego ejecuto TODO automáticamente. 🚀

