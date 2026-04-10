# Plan de Implementacion Ejecutable — Backend Firestore
Fecha: 2026-03-16
Estado: READY FOR EXECUTION
Alcance: backend firestore-only (observabilidad, errores, hardening datos, permisos, performance, release gates)

---

## 1. Objetivo

Implementar las 7 mejoras priorizadas del backend para operar firestore-only con:
- contratos de error uniformes,
- observabilidad completa,
- tolerancia a datos malformados,
- autorizacion auditable,
- consultas Firestore optimizadas,
- y gate E2E remoto obligatorio post-deploy.

---

## 2. Estructura por Epicas

### EPIC E1 — Observabilidad Estandar
Objetivo:
- trazabilidad por request, usuario, proyecto y endpoint.

Historias:
- E1-S1: middleware de trace_id para todas las requests.
- E1-S2: logging estructurado JSON en endpoints criticos.
- E1-S3: incluir request_id, user_id, project_id, route, latency_ms en logs.

Criterios de aceptacion:
- Toda respuesta (ok/error) tiene trace_id disponible (header o body error).
- Logs de errores 4xx/5xx incluyen contexto minimo operativo.
- Se puede correlacionar una falla de cliente con una linea de log en < 2 min.

Archivos foco:
- backend/app/main.py
- backend/app/api/deps.py
- backend/app/api/v1/sync.py
- backend/app/api/v1/review.py

---

### EPIC E2 — Contrato de Errores Unificado
Objetivo:
- estandarizar errores API para frontend y soporte.

Historias:
- E2-S1: definir schema unico: code, message, details, trace_id.
- E2-S2: helper central para construir HTTPException estandarizada.
- E2-S3: migrar endpoints criticos a contrato uniforme.

Criterios de aceptacion:
- 100% de endpoints criticos devuelven mismo shape de error.
- No hay mensajes sueltos inconsistentes para casos equivalentes.
- Tests de contrato cubren al menos auth/sync/review/activities.

Archivos foco:
- backend/app/api/v1/auth.py
- backend/app/api/v1/sync.py
- backend/app/api/v1/review.py
- backend/app/api/v1/activities.py

---

### EPIC E3 — Hardening de Datos Firestore
Objetivo:
- evitar 500 por documentos historicos o malformados.

Historias:
- E3-S1: normalizadores/coercion segura por entidad Firestore.
- E3-S2: descarte controlado de registros invalidos con log de diagnostico.
- E3-S3: fallback no bloqueante en pull/push/listados criticos.

Criterios de aceptacion:
- Pull/push no falla global por 1 documento invalido.
- Registros invalidos quedan trazados con code de data-quality.
- No hay regresion en e2e firestore smoke.

Archivos foco:
- backend/app/api/v1/sync.py
- backend/app/services/firestore_identity_service.py
- backend/app/api/v1/review.py

---

### EPIC E4 — Pruebas de Regresion (Datos Sucios)
Objetivo:
- blindar backend contra fallas ya vistas en produccion.

Historias:
- E4-S1: fixtures de documentos corruptos/incompletos.
- E4-S2: pruebas negativas para sync pull/push.
- E4-S3: pruebas auth/review con payload edge-case.

Criterios de aceptacion:
- Casos sucios agregados en test_sync.py y test_firestore_e2e_flow.py.
- Suite firestore smoke pasa en CI.
- Cobertura de rutas error-handling incrementada.

Archivos foco:
- backend/tests/test_sync.py
- backend/tests/test_firestore_e2e_flow.py
- backend/tests/test_auth.py

---

### EPIC E5 — Autorizacion Auditable
Objetivo:
- hacer explicable cada 403 por rol/scope/proyecto.

Historias:
- E5-S1: logging auditable de deny-overrides.
- E5-S2: registrar motivo de rechazo (permission_code + project_id).
- E5-S3: estandar de mensaje de acceso denegado.

Criterios de aceptacion:
- Todo 403 deja evidencia de regla aplicada.
- Soporte puede reconstruir por que se nego acceso.
- Sin exponer datos sensibles en logs.

Archivos foco:
- backend/app/api/deps.py
- backend/app/api/v1/users.py
- backend/app/api/v1/review.py

---

### EPIC E6 — Performance e Indices Firestore
Objetivo:
- prevenir degradacion de latencia con crecimiento de datos.

Historias:
- E6-S1: inventario de queries criticas (sync/review/catalog).
- E6-S2: matriz de indices requeridos por coleccion.
- E6-S3: runbook de rollout/rollback de indices.

Criterios de aceptacion:
- Lista completa de indices requerida y versionada.
- p95 estable en endpoints criticos post-indices.
- Documentacion operativa actualizada.

Entregables doc:
- docs/RUNBOOK_CLOUD_RUN.md
- docs/SERVICES_MATRIX.md

---

### EPIC E7 — Release Gate E2E Remoto
Objetivo:
- bloquear releases con deploy exitoso pero flujo roto.

Historias:
- E7-S1: job post-deploy que ejecuta e2e_staging_flow.py.
- E7-S2: publicacion de evidencia (uuid, push status, estado final).
- E7-S3: politica de rollback cuando E2E falla.

Criterios de aceptacion:
- Pipeline no se considera verde sin E2E remoto PASS.
- Evidencia automatica en artifacts/log resumen.
- Procedimiento de rollback documentado y probado.

Archivos foco:
- .github/workflows/backend-ci.yml
- backend/scripts/e2e_staging_flow.py
- docs/RUNBOOK_E2E_STAGING.md

---

## 3. Backlog en Formato de Tickets

Formato sugerido:
- ID: BF-<epic>-<numero>
- Tipo: Story / Task / Bug
- Prioridad: P0/P1/P2
- Estimacion: 1,2,3,5 puntos

Backlog inicial (orden recomendado):

### Sprint 1 (P0)
- BF-E1-01 (Story, 3): middleware trace_id + propagacion.
- BF-E2-01 (Story, 3): schema de error unificado y helper central.
- BF-E2-02 (Task, 2): migrar auth + sync al nuevo contrato.
- BF-E3-01 (Story, 3): coercion segura sync_version/fechas en sync.
- BF-E4-01 (Task, 2): tests de documentos malformados en pull.

### Sprint 2 (P0/P1)
- BF-E2-03 (Task, 3): migrar review + activities + users a contrato error.
- BF-E3-02 (Story, 3): hardening adicional review/catalog payloads.
- BF-E4-02 (Task, 2): ampliar e2e firestore con casos edge.
- BF-E5-01 (Story, 3): auditoria completa de denegaciones 403.

### Sprint 3 (P1)
- BF-E6-01 (Story, 3): inventario de queries e indices firestore.
- BF-E6-02 (Task, 2): documentar y aplicar indices prioritarios.
- BF-E7-01 (Story, 3): gate E2E remoto en workflow.
- BF-E7-02 (Task, 2): resumen de evidencia + rollback policy.

---

## 4. Dependencias

- E2 depende de E1 (trace_id disponible para errores).
- E4 depende de E3 (primero hardening, luego tests de regresion completos).
- E7 depende de E2/E3/E4 (gate estable sobre comportamiento final).
- E6 puede ejecutarse en paralelo desde Sprint 2.

---

## 5. Riesgos y Mitigaciones

Riesgo 1: migracion parcial de contrato de errores.
- Mitigacion: checklist por endpoint + test de contrato.

Riesgo 2: documentos legacy rompen nuevas rutas.
- Mitigacion: parser defensivo + logs data-quality + tests sucios.

Riesgo 3: gate E2E inestable por datos de entorno.
- Mitigacion: usuario operativo dedicado + proyecto fijo + fallback controlado.

---

## 6. Definicion de Hecho (DoD Global)

Se considera cerrado cuando:
- Firestore smoke suite pasa en CI.
- E2E remoto post-deploy pasa de forma consistente.
- Error contract uniforme en endpoints criticos.
- 403 auditables con causa explicita.
- Runbooks y matriz de servicios/indices actualizados.

---

## 7. Evidencia Minima por Sprint

Cada sprint debe adjuntar:
- listado de PRs merged,
- salida de tests relevantes,
- evidencia de deploy/staging,
- cambios documentales actualizados,
- riesgos abiertos y plan de cierre.

---

## 8. Comando de Validacion Unificado

Smoke local firestore-only:
- backend/scripts/run_firestore_regression_smoke.ps1

E2E remoto staging/prod controlado:
- backend/scripts/e2e_staging_flow.py

Este plan queda listo para cargarse a Jira/GitHub Projects en formato de epicas e historias.

---

## 9. Plan de Eliminacion SQL (Inicio 2026-03-16)

Objetivo:
- retirar componentes SQL sin afectar operacion firestore-only en produccion.

Estrategia:
- eliminacion incremental por riesgo, con validacion en cada fase.

### Fase A (Riesgo Bajo) - En ejecucion
- remover parametros SQL de scripts operativos de deploy firestore-only.
- eliminar referencias runtime a Cloud SQL y DATABASE_URL en CI/deploy.
- mantener pruebas smoke/E2E como gate obligatorio.

Estado Fase A:
- completado: deploy runtime firestore-only estricto (sin cloudsql-instances y sin DATABASE_URL en Cloud Run).
- completado: workflow deploy actualiza env firestore-only y limpia secretos SQL runtime.
- completado: `tools/deploy/deploy_to_cloud_run.ps1` ya no expone parametros SQL obsoletos.

### Fase B (Riesgo Medio)
- identificar endpoints que aun tienen ramas SQL fallback y migrarlos a implementacion firestore nativa.
- convertir respuestas `SQL_DB_UNAVAILABLE` en rutas funcionales firestore (o remover endpoints obsoletos).
- ampliar pruebas de regresion por dominio (users, territory, review, reports).

Estado Fase B:
- en ejecucion.
- completado: `GET /territory/locations/states` ahora resuelve estados/municipios desde `projects.location_scope` en Firestore (sin dependencia SQL).
- completado: `GET /territory/locations/states` sin rama SQL legacy (Firestore-only estricto).
- completado: `GET /territory/fronts` migrado a firestore-only (fallback SQL removido).
- completado: `POST /territory/fronts`, `GET /territory/locations` y `PUT /territory/projects/{project_id}/locations` migrados a firestore-only (eliminadas ramas SQL y `SQL_DB_UNAVAILABLE`).
- completado: `GET /reports/activities` migrado a Firestore-only (removido fallback SQL para reportes operativos).
- completado: `GET /users/admin/permissions` y `GET /users/admin/role-permissions` operan firestore-only (sin ramas SQL).
- completado: `GET /users` y `GET /users/admin` migrados a firestore-only (fallback SQL removido).
- completado: `POST /users/admin` y `PATCH /users/admin/{user_id}` migrados a firestore-only (eliminadas ramas SQL y `SQL_DB_UNAVAILABLE` en users).
- completado: `GET /review/queue` migrado a firestore-only (fallback SQL removido).
- completado: `GET /review/activity/{activity_id}` migrado a firestore-only (fallback SQL removido).
- completado: `GET /review/activity/{activity_id}/evidences`, `GET /review/reject-playbook` y `POST /review/reject-reasons` migrados a firestore-only.
- completado: `POST /review/evidence/{evidence_id}/validate` y `PATCH /review/evidence/{evidence_id}` migrados a firestore-only.
- completado: `POST /review/activity/{activity_id}/decision` migrado a firestore-only.
- completado: `backend/app/api/v1/review.py` sin ramas SQL fallback (`SQL_DB_UNAVAILABLE` eliminado del modulo).
- completado: `backend/app/api/v1/assignments.py` migrado a firestore-only (`GET /assignments`, `GET /assignments/assignees`, `POST /assignments`, `POST /assignments/{assignment_id}/cancel`).
- completado: `backend/app/api/v1/activities.py` migrado a firestore-only (`create/list/get/update/delete/flags/timeline`) y sin ramas SQL fallback.
- completado: `backend/app/api/v1/auth.py` migrado a firestore-only (signup/roles/login/refresh/me/logout/password/pin).
- completado: `backend/app/api/v1/sync.py` con endpoints `pull/push` operando firestore-only y sin `SQL_DB_UNAVAILABLE`.
- completado: `backend/app/api/v1/dashboard.py` migrado a firestore-only (`GET /dashboard/kpis`).
- completado: `backend/app/api/v1/catalog.py` migracion incremental a firestore-only.
- completado (catalog, bloque 1): `GET /catalog/latest`, `GET /catalog/check-updates`, `GET /catalog/versions`, `GET /catalog/versions/{version_id}`, `POST /catalog/versions/{version_id}/publish`.
- completado (catalog, bloque 2): `GET /catalog/effective`, `GET /catalog/version/current`, `GET /catalog/diff`, `GET /catalog/bundle`, `GET /catalog/workflow`, `PATCH /catalog/project-ops`, `POST /catalog/validate`, `POST /catalog/publish`, `POST /catalog/rollback`.
- completado (catalog, bloque 3): `GET /catalog/editor` y operaciones editor para `activities`, `subcategories`, `purposes`, `topics`, `results`, `attendees`, `rel-activity-topics`, `reorder` en firestore-only.
- completado: `backend/app/api/v1/observations.py` migrado a firestore-only (`POST /observations`, `GET /mobile/observations`, `POST /mobile/observations/{observation_id}/resolve`).
- completado: `backend/app/api/v1/me.py` migrado a firestore-only (`GET /me/projects`).
- completado: `backend/app/api/v1/audit.py` migrado a firestore-only (`GET /audit`).
- completado: `backend/app/api/v1/evidences.py` migrado a firestore-only (`upload-init`, `upload-complete`, `download-url`, `local-upload`).
- completado: `backend/app/api/v1/events.py` migrado a firestore-only (`create/list/get/update/delete`) sin ramas `dual/postgres`.
- completado: `backend/app/api/v1/ocr.py` migrado a firestore-only (`POST /ocr/link`).
- completado: bloque CRUD principal de `backend/app/api/v1/projects.py` migrado a firestore-only (`GET /projects`, `POST /projects`, `PUT /projects/{project_id}`, `DELETE /projects/{project_id}`).
- completado: limpieza residual en `backend/app/api/v1/sync.py` (helper de compatibilidad sin dependencia directa a `DATA_BACKEND`).
- completado: limpieza residual en `backend/app/api/v1/review.py` (removido helper `dual` legacy; `DATA_BACKEND` eliminado del modulo).
- completado: `backend/app/api/v1/catalog.py` sin helper SQL residual (`_require_catalog_sql_db`) ni imports `get_db/get_db_optional`.
- completado: `backend/app/api/v1/debug.py` migrado a Firestore-only (`GET /debug/users-with-activities` sin dependencia SQL).
- completado: limpieza de imports SQL legacy en `backend/app/api/v1/review.py` y `backend/app/api/v1/projects.py` (sin `get_db/get_db_optional`).
- verificado: `backend/app/api/v1/*.py` sin ocurrencias de `settings.DATA_BACKEND`.

### Fase C (Riesgo Medio/Alto)
- retirar dependencias SQL del backend principal (`alembic`, `psycopg2`) en runtime firestore-only.
- reducir consumidores ORM en routers firestore-only para desacoplar runtime de ramas SQL legacy.
- limpiar documentacion operativa y runbooks legacy.

Estado Fase C:
- completado: imagen principal `backend/Dockerfile` instala perfil `requirements.firestore-runtime.txt` (sin `alembic` ni `psycopg2-binary`).
- completado: `backend/app/api/v1/sync.py` sin imports `sqlalchemy` ni helpers SQL muertos.
- completado: `backend/app/api/v1/review.py` sin imports ORM/modelos SQL legacy y con helpers SQL eliminados.
- completado: base para desacople total de `sqlalchemy` en runtime (pendiente solo migracion de enums/modelos compartidos en modulos no bloqueantes para Fase D).

### Fase D (Cierre)
- congelar `DATA_BACKEND` a firestore en configuracion de aplicacion.
- remover modos `postgres` y `dual` del codigo.
- ejecutar hardening final + auditoria de codigo para asegurar cero rutas SQL activas.

Estado Fase D:
- en ejecucion.
- completado: routers `backend/app/api/v1/*.py` sin imports directos `sqlalchemy` ni `app.models.*`.
- completado: enums compartidos movidos a `backend/app/core/enums.py` y consumidos por `schemas`/routers firestore-only.
- completado: `backend/app/main.py` y `backend/app/api/deps.py` desacoplados de imports SQL en carga de modulo (imports SQL ahora lazy y solo para ramas legacy no-firestore).
- completado: `backend/requirements.firestore-runtime.txt` sin `sqlalchemy` (runtime firestore-only estricto).
- pendiente: remocion definitiva de ramas `postgres/dual` en servicios legacy y limpieza de tooling SQL de desarrollo.

Exit criteria global:
- produccion y CI pasan 100% en firestore-only durante 2 semanas sin incidentes.
- no existen referencias activas a DATABASE_URL/Cloud SQL en runtime.
- no existen endpoints productivos con fallback SQL.
