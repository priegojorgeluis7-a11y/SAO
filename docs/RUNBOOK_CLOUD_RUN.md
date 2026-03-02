# Runbook Cloud Run + Cloud SQL (SAO)

Guia paso a paso para dejar el backend en produccion con Cloud Run y Cloud SQL.

## 1) Variables base

```powershell
$PROJECT="sao-prod-488416"
$REGION="us-central1"
$INSTANCE="sao-postgres-ent"
$CONN="$PROJECT:$REGION:$INSTANCE"
$DB_NAME="sao"
$DB_USER="sao_user"
$DB_PASS="REEMPLAZAR_PASSWORD_FUERTE"

# Cloud Run defaults
$CPU="1"
$MEMORY="512Mi"
$MIN_INSTANCES=0
$MAX_INSTANCES=10
$TIMEOUT=300
$CONCURRENCY=80
```

## 2) Cloud SQL (Postgres)

```powershell
gcloud sql instances create $INSTANCE `
  --database-version=POSTGRES_15 `
  --cpu=2 `
  --memory=8GB `
  --region $REGION `
  --availability-type=ZONAL `
  --backup-start-time=03:00

gcloud sql databases create $DB_NAME --instance $INSTANCE

gcloud sql users create $DB_USER `
  --instance $INSTANCE `
  --password $DB_PASS
```

## 3) Secret Manager

```powershell
$DB_PASS="REEMPLAZAR_PASSWORD_FUERTE"
$JWT_SECRET="REEMPLAZAR_JWT"
$GCS_BUCKET="REEMPLAZAR_BUCKET"

# DATABASE_URL para Cloud Run + Cloud SQL socket
$DATABASE_URL="postgresql+psycopg://$DB_USER:$DB_PASS@/$DB_NAME`?host=/cloudsql/$CONN"

echo $DATABASE_URL | gcloud secrets create DATABASE_URL --data-file=-
echo $JWT_SECRET | gcloud secrets create JWT_SECRET --data-file=-
echo $GCS_BUCKET | gcloud secrets create GCS_BUCKET --data-file=-
```

**Nota:** El pattern `postgresql+psycopg://` es el correcto para SQLAlchemy 2.0 + psycopg3 con unix socket.

## 4) Service Account + IAM

```powershell
$SA_NAME="sao-runner"
$SA_EMAIL="$SA_NAME@$PROJECT.iam.gserviceaccount.com"

gcloud iam service-accounts create $SA_NAME --display-name "SAO Cloud Run"

gcloud projects add-iam-policy-binding $PROJECT `
  --member "serviceAccount:$SA_EMAIL" `
  --role "roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT `
  --member "serviceAccount:$SA_EMAIL" `
  --role "roles/secretmanager.secretAccessor"
```

## 5) Build imagen

```powershell
cd D:\SAO\backend
gcloud builds submit --tag gcr.io/$PROJECT/sao-api
```

## 6) Deploy Cloud Run (API)

```powershell
gcloud run deploy sao-api `
  --image gcr.io/$PROJECT/sao-api `
  --region $REGION `
  --service-account $SA_EMAIL `
  --cpu $CPU `
  --memory $MEMORY `
  --min-instances $MIN_INSTANCES `
  --max-instances $MAX_INSTANCES `
  --timeout $TIMEOUT `
  --concurrency $CONCURRENCY `
  --add-cloudsql-instances $CONN `
  --set-secrets DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest,GCS_BUCKET=GCS_BUCKET:latest `
  --allow-unauthenticated=false
```

**Defaults usados:**
- `CPU: 1` (ajusta a 2 si ves spike de CPU)
- `Memory: 512Mi` (sube a 1Gi si ves OOM)
- `Min instances: 0` (ahorra dinero; cambia a 1 si quieres evitar cold start)
- `Max instances: 10` (ajusta luego según tráfico real)
- `Timeout: 300s` (5 min; baja a 60-120s si tus endpoints son rápidos)
- `Concurrency: 80` (buena base; baja a 20-40 si haces CPU/DB heavy)

## 7) Cloud Run Job (migraciones + seeds)

```powershell
gcloud run jobs create sao-migrate `
  --image gcr.io/$PROJECT/sao-api `
  --region $REGION `
  --service-account $SA_EMAIL `
  --add-cloudsql-instances $CONN `
  --set-secrets DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest `
  --command "python" `
  --args "-m","scripts.run_migrations_and_seed" `
  --cpu $CPU `
  --memory $MEMORY `
  --timeout 600

gcloud run jobs execute sao-migrate --region $REGION
```

**Nota:** El job usa `timeout 600` (10 min) porque migraciones + seeds pueden tardar. Ajusta si es necesario.

## 8) Verificacion

```powershell
# URL del servicio
gcloud run services describe sao-api --region $REGION --format="value(status.url)"

# Health check (si no requiere auth)
$URL=(gcloud run services describe sao-api --region $REGION --format="value(status.url)")
curl $URL/health

# Revisar logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=sao-api" --limit 20
```

## 9) Observabilidad minima

```powershell
# Ver URL del servicio
gcloud run services describe sao-api --region $REGION --format="value(status.url)"

# Logs en tiempo real
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=sao-api" `
  --region $REGION `
  --limit 50

# Crear uptime check (desde Cloud Logging/Cloud Monitoring)
# - Target: https://<SERVICE_URL>/health
# - Frecuencia: 60s
```

## 10) Notas de seguridad

- Rotar `JWT_SECRET` cada 90 días (recrear secret y redeployed).
- Restringir `CORS_ORIGINS` en produce (no "*").
- Monitorear 5xx y latencia en Cloud Logging.
- Backups automáticos de Cloud SQL habilitados.
- No usar `--allow-unauthenticated` en produccion (requiere IAM o autenticacion).

## 11) Cold Start (opcional)

Si el equipo usa la API diario y quieres evitar demora en primera peticion:

```powershell
# Cambiar min-instances a 1
gcloud run services update sao-api `
  --region $REGION `
  --min-instances 1
```
