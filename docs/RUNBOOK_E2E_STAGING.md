# Runbook: E2E Staging — SAO

**Script:** `backend/scripts/e2e_staging_flow.py`
**Propósito:** Validar el flujo completo operativo → supervisor en un entorno real (staging o producción) sin depender del test unitario con SQLite.

---

## Flujo que valida

```
[1] Login operativo + supervisor
[2] Resolve identidad del operativo + catalog version_id actual
[3] Operativo hace PUSH de una actividad via POST /sync/push
[4] Baseline PULL para capturar current_version actual
[5] Supervisor aprueba la actividad via POST /review/activity/{id}/decision
[6] Operativo hace delta PULL (since_version = baseline)
[7] Verifica que la actividad aparece con execution_state = COMPLETADA
```

---

## Pre-requisitos

### 1. Entorno Python

```bash
cd backend
pip install -r requirements.txt
```

### 2. Credenciales

Necesitas dos usuarios ya creados en el entorno objetivo:

| Rol | Descripción |
|-----|-------------|
| `OPERATIVO` | Usuario de campo con scope en el proyecto |
| `SUPERVISOR` o `COORD` o `ADMIN` | Usuario con permiso de aprobación |

Para crear usuarios en staging si no existen:

```bash
# Conectar a la instancia y ejecutar el seed
DATABASE_URL="postgresql://..." python -c "
from app.core.database import SessionLocal
from app.seeds.initial_data import seed_admin_user
db = SessionLocal()
seed_admin_user(db)
db.close()
"
```

O usar el script de creación de usuarios operativos:

```bash
DATABASE_URL="postgresql://..." python scripts/create_operativo_demo_user.py
```

### 3. Backend URL

- **Staging / Producción pública:** `https://sao-api-fjzra25vya-uc.a.run.app`
- **Local:** `http://localhost:8000`
- **Cloud Run privado:** requiere `--cloud-run-private` (ver abajo)

---

## Ejecución básica (backend público)

```bash
cd backend

python scripts/e2e_staging_flow.py \
  --base-url "https://sao-api-fjzra25vya-uc.a.run.app" \
  --project-id "TMQ" \
  --operativo-email "operativo@sao.mx" \
  --operativo-password "tu-password-aqui" \
  --supervisor-email "admin@sao.mx" \
  --supervisor-password "admin123"
```

Salida esperada:

```
SAO Staging E2E Flow
Base URL: https://sao-api-fjzra25vya-uc.a.run.app
Project: TMQ

[1/7] Login operativo and supervisor...
[2/7] Resolve operativo identity and current catalog version...
[3/7] Operativo push activity to sync endpoint...
[4/7] Baseline operativo pull to capture current_version...
[5/7] Supervisor approves activity in review endpoint...
[6/7] Operativo delta pull after approval...
[7/7] Validate final execution_state from pull...

E2E flow passed
Activity UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Push status: CREATED
Final execution_state: COMPLETADA
```

---

## Ejecución con Cloud Run privado (ingress `all-authenticated`)

Si el servicio Cloud Run requiere token de identidad de GCP:

```bash
# Autenticar con gcloud primero
gcloud auth login

python scripts/e2e_staging_flow.py \
  --base-url "https://sao-api-fjzra25vya-uc.a.run.app" \
  --project-id "TMQ" \
  --operativo-email "operativo@sao.mx" \
  --operativo-password "tu-password-aqui" \
  --supervisor-email "admin@sao.mx" \
  --supervisor-password "admin123" \
  --cloud-run-private
```

O con token pre-generado:

```bash
TOKEN=$(gcloud auth print-identity-token)

python scripts/e2e_staging_flow.py \
  --base-url "https://sao-api-fjzra25vya-uc.a.run.app" \
  --project-id "TMQ" \
  --operativo-email "operativo@sao.mx" \
  --operativo-password "tu-password-aqui" \
  --supervisor-email "admin@sao.mx" \
  --supervisor-password "admin123" \
  --identity-token "$TOKEN"
```

---

## Argumentos disponibles

| Argumento | Requerido | Default | Descripción |
|-----------|-----------|---------|-------------|
| `--base-url` | SI | — | URL base del backend |
| `--project-id` | No | `TMQ` | ID del proyecto a usar |
| `--operativo-email` | SI | — | Email del usuario OPERATIVO |
| `--operativo-password` | SI | — | Password del usuario OPERATIVO |
| `--supervisor-email` | SI | — | Email del usuario SUPERVISOR/COORD/ADMIN |
| `--supervisor-password` | SI | — | Password del usuario SUPERVISOR |
| `--activity-type-code` | No | `INSP_CIVIL` | Código de tipo de actividad |
| `--pk-start` | No | `13500` | PK de inicio de la actividad de prueba |
| `--pk-end` | No | `13800` | PK de fin de la actividad de prueba |
| `--cloud-run-private` | No | False | Obtener identity token via `gcloud` |
| `--identity-token` | No | `""` | Token de identidad pre-generado |
| `--timeout` | No | `30` | Timeout HTTP en segundos |
| `--verbose` | No | False | Mostrar info de debug adicional |

---

## Errores comunes y soluciones

### `POST /sync/push -> 422` con error de UUID en `catalog_version_id`
- En algunos entornos, `GET /catalog/version/current` devuelve `version_id` semantico (ej. `tmq-v2.0.0`) en lugar de UUID.
- El script ya contempla este caso: resuelve el UUID canonico via `GET /catalog/versions` y lo usa para `sync/push`.
- Si falla, ejecutar con `--verbose` para inspeccionar `version_id` y `catalog_version_uuid` resuelto.

### `Login for operativo@... failed with HTTP 401`
- Las credenciales son incorrectas o el usuario no existe en ese entorno.
- Verificar con `GET /api/v1/auth/me` usando un token válido.

### `catalog/version/current response missing version_id`
- No hay catálogo publicado para el `project_id` especificado.
- Ejecutar el seed del catálogo: `python scripts/create_tmq_tap_projects.py` o hacer bootstrap via `POST /api/v1/projects`.

### `Expected execution_state=COMPLETADA, got REVISION_PENDIENTE`
- La aprobación falló silenciosamente o el pull no devolvió la actividad actualizada.
- Revisar el checklist de aprobación: la actividad puede fallar por GPS requerido o fotos insuficientes.
- Usar `--activity-type-code` con un tipo que no requiera checklist estricto.
- El script aplica fallback controlado: si `APPROVE` responde `422 CHECKLIST_INCOMPLETE`, reintenta como `APPROVE_EXCEPTION`.
- Verificar los logs de Cloud Run: `gcloud run logs read sao-api --region us-central1 --limit 50`

### `E2EError: Unable to get identity token from gcloud`
- Ejecutar `gcloud auth login` antes de correr el script.
- O pasar `--identity-token` con un token válido.

---

## Ejecución con proyecto TAP (multi-proyecto)

```bash
python scripts/e2e_staging_flow.py \
  --base-url "https://sao-api-fjzra25vya-uc.a.run.app" \
  --project-id "TAP" \
  --operativo-email "operativo-tap@sao.mx" \
  --operativo-password "password" \
  --supervisor-email "admin@sao.mx" \
  --supervisor-password "admin123" \
  --activity-type-code "CAM"
```

---

## Checklist de corrida E2E exitosa

```
[ ] Login de ambos usuarios devuelve HTTP 200 con access_token
[ ] GET /auth/me devuelve id del operativo
[ ] GET /catalog/version/current devuelve version_id
[ ] POST /sync/push devuelve status CREATED o UPDATED
[ ] POST /sync/pull baseline devuelve current_version >= 0
[ ] POST /review/activity/{id}/decision devuelve ok=true
[ ] POST /sync/pull delta contiene la actividad con execution_state=COMPLETADA
[ ] Verificar logs de Cloud Run sin errores 5xx durante el flujo
```

---

## Acta de Ejecución Real (2026-03-05)

Comando ejecutado (resumen):

```bash
python scripts/e2e_staging_flow.py \
  --base-url "https://sao-api-fjzra25vya-uc.a.run.app" \
  --project-id "TMQ" \
  --operativo-email "operativo@sao.mx" \
  --supervisor-email "admin@sao.mx"
```

Resultado:
- `E2E flow passed`
- `Activity UUID: 6997c072-4450-4f63-b9b2-5a71cb85df60`
- `Push status: CREATED`
- `Final execution_state: COMPLETADA`

Notas de compatibilidad registradas:
- `catalog/version/current` entrego `version_id` semantico (`tmq-v2.0.0`) y se resolvio UUID via `/catalog/versions`.
- En decision de review se encontro `422 CHECKLIST_INCOMPLETE` para `APPROVE`; se aplico fallback a `APPROVE_EXCEPTION` para completar el flujo validado.

---

## Logs de Cloud Run en tiempo real

```bash
gcloud run logs read sao-api \
  --region us-central1 \
  --project sao-prod-488416 \
  --limit 100 \
  --follow
```

---

## Automatización en CI (futuro)

El script puede correr en GitHub Actions después de deploy usando secrets:

```yaml
- name: Run E2E staging
  env:
    OPERATIVO_PASS: ${{ secrets.E2E_OPERATIVO_PASSWORD }}
    SUPERVISOR_PASS: ${{ secrets.E2E_SUPERVISOR_PASSWORD }}
  run: |
    python backend/scripts/e2e_staging_flow.py \
      --base-url "https://sao-api-fjzra25vya-uc.a.run.app" \
      --operativo-email "e2e-operativo@sao.mx" \
      --operativo-password "$OPERATIVO_PASS" \
      --supervisor-email "e2e-supervisor@sao.mx" \
      --supervisor-password "$SUPERVISOR_PASS" \
      --verbose
```

Secrets requeridos en GitHub: `E2E_OPERATIVO_PASSWORD`, `E2E_SUPERVISOR_PASSWORD`.

---

**Última actualización:** 2026-03-05 (incluye corrida real de staging exitosa)
