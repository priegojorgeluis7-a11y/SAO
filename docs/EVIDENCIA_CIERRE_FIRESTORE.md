# Evidencia de Cierre - Migracion Firestore (Prellenado)

**Fecha inicio:** 2026-03-09  
**Fecha corte:** 2026-03-10  
**Responsable:** Equipo SAO  
**Entorno:** Produccion controlada (Cloud Run `sao-api`, `us-central1`)  
**Version backend:** desplegado hasta revision `sao-api-00062-v8v`  
**Cloud Run revision activa:** `sao-api-00062-v8v`

## 1. Resumen Ejecutivo
- Estado final: **GO** (flujo principal validado end-to-end en produccion).
- Riesgos abiertos: monitoreo post-incidente Cloud Run por 7 dias y cobertura desktop no-auth por ampliar.
- Incidentes durante ventana: `429 no available instance` mitigado y documentado en `docs/INCIDENTE_CLOUD_RUN_429_2026-03-10.md`.
- Decision sobre Cloud SQL: **desacoplado del runtime de Cloud Run**.

## 2. P0 - Bloqueantes

### 2.1 Inventario endpoints SQL-dependientes
- Archivo evidencia: `docs/SERVICES_MATRIX.md`
- Estado: **Ejecutado con scan tecnico**.
- Resultado: **PASS (inventario generado)**

### 2.2 Auth/Authz firestore-only
- Estado observado: auth basico firestore-only ya funcional.
- Evidencia existente:
  - `backend/tests/test_auth.py`
  - `backend/tests/test_firestore_e2e_flow.py`
- Resultado: **PARCIAL / pendiente cierre formal PASS**

### 2.3 Catalogo firestore-only
- Estado: implementado en endpoints criticos (`current`, `effective`, `bundle/workflow`, `versions`, admin ops).
- Evidencia:
  - `backend/tests/test_catalog_bundle.py`
- Resultado: **PARCIAL (funcional), pendiente cierre de regresion total**

### 2.4 Sync critico firestore-only
- Estado: implementado `sync/pull` y `sync/push` con validaciones de catalogo.
- Evidencia:
  - `backend/tests/test_sync.py`
  - `backend/tests/test_firestore_e2e_flow.py`
- Resultado: **PASS (flujo E2E real operativo->review->pull ejecutado en prod controlada)**

### 2.5 Backfill y paridad
- Estado confirmado:
  - `events`: OK
  - `activities`: OK (tras backfill TMQ)
- Evidencia:
  - `backend/parity_report_tmq.json`
  - `backend/scripts/verify_firestore_parity.py`
  - `backend/scripts/backfill_firestore_from_postgres.py`
- Resultado: **PASS parcial (TMQ)**; falta ampliar a entidades/proyectos remanentes.

## 3. P1 - Estabilizacion

### 3.1 Regresion backend firestore-only
- Smoke suite existente e integrada en CI.
- Resultado reportado:
  - catalog: 4 passed
  - sync: 2 passed
  - auth: 3 passed
  - integrado: 3 passed
- Estado: **PARCIAL (hay base, falta ampliar cobertura)**

### 3.2 E2E funcional real
- Estado: flujo real ejecutado en produccion controlada con usuarios de prueba dedicados.
- Resultado: **PASS (flujo principal base en TMQ)**

### 3.3 Observabilidad y alertas
- Estado: no hay evidencia consolidada de dashboard+alertas cerradas en el corte.
- Resultado: **FAIL (pendiente)**

### 3.4 Seguridad operativa
- Estado: pendiente evidencia formal de rotacion de secretos de prueba + validacion IAM minima.
- Resultado: **FAIL (pendiente)**

## 4. P2 - Cierre tecnico

### 4.1 Limpieza tecnica
- Dual-write/flags legacy: aun no retirados de forma final.
- Scripts/seeds SQL legacy: limpieza pendiente.
- Resultado: **FAIL (pendiente)**

### 4.2 Documentacion actualizada
- Plan de migracion actualizado (`docs/PLAN_MIGRACION_FIRESTORE.md`).
- Pendiente actualizar cierre final en:
  - `docs/RUNBOOK_CLOUD_RUN.md`
  - `ARCHITECTURE.md`
  - `docs/WORKFLOW.md`
- Resultado: **PARCIAL**

## 5. Avances de produccion confirmados en este corte
- Backend desplegado en prod con fixes recientes.
- Home:
  - ya sincroniza y ya tiene proyectos visibles (tras seed/base projects).
- Agenda:
  - ya devuelve recurso operativo (`/users?role=OPERATIVO` con datos).
- Verificaciones de API realizadas:
  - `/api/v1/me/projects` > 0
  - `/api/v1/projects` > 0
  - `/api/v1/users?role=OPERATIVO` > 0

## 6. DoD (Definition of Done)
- [x] `DATA_BACKEND=firestore` en produccion, sin fallback operativo a PostgreSQL
- [ ] Endpoints criticos de negocio sin dependencia SQL
- [x] E2E principal PASS en firestore-only
- [ ] Monitoreo sin incidentes severos durante 7 dias
- [ ] Documentacion operativa y tecnica actualizada

## 7. Decision de corte (hoy)
- Decision: **GO operativo**
- Motivo: runtime Firestore-only estable, smoke en verde y E2E real PASS en produccion.

## 8. Ejecucion del plan (2026-03-10)

### 8.1 Regresion firestore-only ejecutada
- Comando ejecutado:
  - `./backend/scripts/run_firestore_regression_smoke.ps1`
- Resultado:
  - `backend/tests/test_catalog_bundle.py`: **4 passed**
  - `backend/tests/test_sync.py`: **2 passed**
  - `backend/tests/test_auth.py`: **3 passed**
  - `backend/tests/test_firestore_e2e_flow.py`: **3 passed**
- Estado: **PASS**

### 8.2 Validaciones operativas ya confirmadas en produccion
- `GET /api/v1/me/projects`: con datos (>0)
- `GET /api/v1/projects`: con datos (>0)
- `GET /api/v1/users?role=OPERATIVO`: con datos (>0)
- Estado: **PASS**

### 8.3 Siguiente accion para cierre P0/P1
- Ejecutar E2E funcional real contra entorno objetivo con credenciales operativas/supervision vigentes.
- Bloqueo actual: no hay credenciales operativas/supervisor documentadas en este repo para corrida automatica inmediata.

### 8.4 Comando preparado para ejecucion E2E real
- Script: `backend/scripts/e2e_staging_flow.py`
- Ejecucion sugerida:
  - `D:/SAO/.venv/Scripts/python.exe backend/scripts/e2e_staging_flow.py --base-url "https://sao-api-97150883570.us-central1.run.app" --project-id "TMQ" --operativo-email "<operativo_email>" --operativo-password "<operativo_password>" --supervisor-email "<supervisor_email>" --supervisor-password "<supervisor_password>" --cloud-run-private --verbose`

### 8.5 E2E real ejecutado (produccion controlada)
- Usuarios de prueba creados por API admin:
  - `operativo.e2e@sao.mx`
  - `supervisor.e2e@sao.mx`
- Hallazgo inicial:
  - `POST /api/v1/review/activity/{id}/decision` devolvia `503 SQL database is disabled for current DATA_BACKEND mode`.
- Accion aplicada:
  - Se agrego rama Firestore en `backend/app/api/v1/review.py` para `review_decision`.
  - Deploy realizado a Cloud Run revision `sao-api-00053-sm5`.
- Resultado final E2E:
  - `✅ E2E flow passed`
  - `Activity UUID: 79995809-157d-4e1b-9733-569c3f446d8d`
  - `Push status: CREATED`
  - `Final execution_state: COMPLETADA`

### 8.9 Cierre final validado (2026-03-10, ventana final)
- Runtime Cloud Run en Firestore-only:
  - `DATA_BACKEND=firestore`
  - `run.googleapis.com/cloudsql-instances: ''`
  - revision activa: `sao-api-00062-v8v`
- Regresion firestore-only en verde (`run_firestore_regression_smoke.ps1`):
  - catalog 4 passed
  - sync 2 passed
  - auth 3 passed
  - firestore_e2e_flow 3 passed
- E2E real final en produccion PASS:
  - `Activity UUID: 328256b9-3ba6-4219-b43e-f78484396f80`
  - `Push status: CREATED`
  - `Final execution_state: COMPLETADA`

### 8.6 Inventario tecnico SQL-dependiente (scan rapido)
- Comando ejecutado:
  - `rg "Depends\\(get_db\\)" backend/app/api/v1 -n`
- Modulos con dependencias SQL directas detectadas:
  - _Sin resultados en `backend/app/api/v1` tras migracion incremental 2026-03-10._
- Nota:
  - Se eliminaron dependencias SQL duras en API v1. Queda pendiente residual `GET /catalog/diff` (flujo SQL en servicio).

### 8.7 Bloque de migracion firestore-only adicional
- Endpoints migrados a Firestore en esta iteracion:
  - `POST/PUT/DELETE /events`
  - `POST /activities`
  - `POST /observations`
  - `GET /mobile/observations`
  - `POST /mobile/observations/{id}/resolve`
  - `POST /evidences/upload-init`
  - `POST /evidences/upload-complete`
  - `GET /evidences/{id}/download-url`
  - `PUT /evidences/local-upload/{id}`
- Deploy aplicado:
  - Cloud Run revision `sao-api-00054-hcg`.
- Verificacion tecnica:
  - smoke firestore-only local/backend en verde.
  - revalidacion E2E post-deploy bloqueada temporalmente por `429 Rate exceeded` en `/api/v1/auth/login` (rate limit del entorno).
