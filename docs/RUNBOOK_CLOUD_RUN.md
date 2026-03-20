# Runbook Cloud Run + Cloud SQL (SAO)

Guia paso a paso para dejar el backend en produccion con Cloud Run y Cloud SQL.

## Estado actual (2026-03-10)

- Servicio activo: `sao-api` en `us-central1`.
- Revision validada: `sao-api-00053-sm5`.
- Config de datos observada en produccion controlada: `DATA_BACKEND=firestore`.
- Flujo E2E validado en entorno real:
  - operativo push -> supervisor decision -> operativo pull
  - resultado final: `execution_state=COMPLETADA`

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

## 12) Flujo E2E en staging (operativo → review → pull)
## 13) Índices Firestore — rollout y rollback

Ver inventario completo en [docs/FIRESTORE_INDEXES.md](FIRESTORE_INDEXES.md).

### Índices compuestos requeridos

| Colección | Campos | Acción si falta |
|-----------|--------|-----------------|
| `catalog_versions` | `project_id ASC, is_current ASC` | Firestore devuelve 400; el backend usa fallback `catalog_current` |
| `catalog_versions` | `project_id ASC, published_at DESC` | Fallback a `is_current` query |

### Rollout — crear índices via Firebase CLI

```bash
# Desde la raíz del repositorio
firebase use sao-prod-488416
firebase deploy --only firestore:indexes
```

O desde la consola GCP: **Firestore > Indexes > Composite > Add Index**.

### Rollout — crear índices via gcloud (sin firebase-tools)

```bash
# catalog_versions: project_id + is_current
gcloud firestore indexes composite create \
  --project sao-prod-488416 \
  --collection-group catalog_versions \
  --field-config field-path=project_id,order=ascending \
  --field-config field-path=is_current,order=ascending \
  --query-scope=COLLECTION

# catalog_versions: project_id + published_at DESC
gcloud firestore indexes composite create \
  --project sao-prod-488416 \
  --collection-group catalog_versions \
  --field-config field-path=project_id,order=ascending \
  --field-config field-path=published_at,order=descending \
  --query-scope=COLLECTION
```

La creación es asíncrona; puede tardar varios minutos. Verificar estado:

```bash
gcloud firestore indexes composite list --project sao-prod-488416
```

### Rollback — eliminar un índice

```bash
# Listar IDs de índices
gcloud firestore indexes composite list --project sao-prod-488416 --format="table(name,state)"

# Borrar por ID (el nombre completo incluye el ID al final)
gcloud firestore indexes composite delete INDEX_NAME --project sao-prod-488416
```

**Impacto del rollback:** el backend tiene fallback para ambos índices — las rutas siguen funcionando
con latencia levemente mayor. Nunca produces 500 por falta de índice.

### Monitoreo de latencia post-índice

```bash
# Ver p95 del endpoint /sync/pull en Cloud Logging (últimas 24h)
gcloud logging read \
  'resource.type="cloud_run_revision" jsonPayload.path="/api/v1/sync/pull"' \
  --project sao-prod-488416 \
  --limit 200 \
  --format "value(jsonPayload.latency_ms)" | sort -n | awk 'NR==int(0.95*NR+0.5)'
```

Script incluido: `backend/scripts/e2e_staging_flow.py`

Valida en orden:
1. Login de operativo y supervisor.
2. Operativo hace `POST /api/v1/sync/push` con actividad de prueba.
3. Supervisor aprueba en `POST /api/v1/review/activity/{id}/decision`.
4. Operativo hace `POST /api/v1/sync/pull` y verifica `execution_state=COMPLETADA`.

### Ejecución (Cloud Run privado con gcloud)

```powershell
cd D:\SAO\backend
python scripts/e2e_staging_flow.py `
  --base-url "https://<tu-servicio-cloud-run>" `
  --project-id "TMQ" `
  --operativo-email "operativo.demo@sao.mx" `
  --operativo-password "<password-operativo>" `
  --supervisor-email "supervisor.demo@sao.mx" `
  --supervisor-password "<password-supervisor>" `
  --cloud-run-private `
  --verbose
```

### Ejecución (si el servicio no requiere identity token)

```powershell
cd D:\SAO\backend
python scripts/e2e_staging_flow.py `
  --base-url "https://<tu-servicio-cloud-run>" `
  --project-id "TMQ" `
  --operativo-email "operativo.demo@sao.mx" `
  --operativo-password "<password-operativo>" `
  --supervisor-email "supervisor.demo@sao.mx" `
  --supervisor-password "<password-supervisor>"
```

### Criterio de éxito

- El script termina con exit code `0`.
- Imprime `✅ E2E flow passed`.
- Reporta `Final execution_state: COMPLETADA`.

## 13) Evidencia reciente (2026-03-10)

- E2E ejecutado con usuarios de prueba dedicados:
  - `operativo.e2e@sao.mx`
  - `supervisor.e2e@sao.mx`
- Hallazgo corregido durante validacion:
  - `POST /api/v1/review/activity/{id}/decision` devolvia `503` en modo firestore.
  - Se implemento rama Firestore en `backend/app/api/v1/review.py`.
- Resultado posterior al deploy:
  - `✅ E2E flow passed`
  - actividad en pull con estado `COMPLETADA`.
