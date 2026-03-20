# Plan de Fix Auditable por Severidad
Fecha: 2026-03-05
Estado de ejecucion: PARCIALMENTE EJECUTADO EN ESTE TURNO

## 1. Hallazgos y estado

### Alta-01: Sync de eventos offline editados antes del primer push
- Riesgo: `create offline -> edit -> sync` podia mutar `UPSERT` a `UPDATE` y romper contra recurso inexistente en servidor.
- Evidencia previa:
  - `events_local_repository.dart` encolaba `UPSERT` en alta y `UPDATE` en edicion.
  - `sync_service.dart` trataba `UPDATE` como `PUT` directo.
- Fix aplicado:
  - Se preserva `UPSERT` al editar si el item en cola aun era `UPSERT`.
- Archivo modificado:
  - `frontend_flutter/sao_windows/lib/features/events/data/events_local_repository.dart`
- Estado: FIX APLICADO.
- Riesgo residual:
  - Escenario `create offline -> delete before first push` requiere regla adicional de anulacion local/no-op remoto.

### Alta-02: `requires_comment` no se aplicaba al rechazar revision
- Riesgo: incumplimiento de regla y trazabilidad incompleta.
- Evidencia previa:
  - Se validaba `reject_reason_code`, pero no comentario obligatorio por razon.
- Fix aplicado:
  - Si `reject_reason.requires_comment == true` y no hay comentario, se retorna `400`.
- Archivo modificado:
  - `backend/app/api/v1/review.py`
- Validacion:
  - Se agrego test de regresion.
  - Archivo: `backend/tests/test_review_observations.py`
- Estado: FIX APLICADO.

### Media-01: CI backend con smoke acoplado a URL fija y deploy publico
- Riesgo: fragilidad del pipeline y exposicion involuntaria.
- Fix aplicado:
  - Se elimina `--allow-unauthenticated` del deploy.
  - Smoke usa URL dinamica de Cloud Run (`gcloud run services describe`) y llamada autenticada por identity token.
- Archivo modificado:
  - `.github/workflows/backend-ci.yml`
- Estado: FIX APLICADO.

### Media-02: CI Flutter ejecutaba solo un test puntual
- Riesgo: regresiones sin detectar.
- Fix aplicado:
  - Step de CI actualizado a `flutter test` completo.
- Archivo modificado:
  - `.github/workflows/flutter-ci.yml`
- Estado: FIX APLICADO.

### Media-03 Seguridad: credenciales demo hardcodeadas
- Riesgo: fuga/reuso involuntario de credenciales.
- Fix aplicado:
  - Password demo ahora se toma de variable de entorno `SAO_DEMO_PASSWORD`.
  - Se evita imprimir password real en stdout.
- Archivo modificado:
  - `backend/scripts/create_operativo_demo_user.py`
- Estado: FIX APLICADO.

### Baja-01: artefactos locales/binarios versionados
- Riesgo: ruido de auditoria y diffs no reproducibles.
- Fix aplicado:
  - Se agregan a `.gitignore`: `/test.db`, `/tools/cloud-sql-proxy.exe`.
- Archivo modificado:
  - `.gitignore`
- Estado: FIX APLICADO.

## 2. Plan de cierre residual (post-fix)

### P0 (bloqueante para 100% funcional)
Estado: CERRADO.

1. Implementar `/me/projects` y consumirlo en mobile.
- Backend: FIX APLICADO (`GET /me/projects`).
- Mobile: FIX APLICADO en selector de proyectos (`ProjectsPage` consume `/me/projects` con fallback controlado).
2. Implementar check ligero multiproyecto: `/catalog/versions?project_ids=...` con respuesta mapa `project -> version/hash`.
- Backend: FIX APLICADO (contrato dual preservando `project_id`).
3. Validar `POST /activities` y `POST /sync/push` contra el `catalog_version_id` exacto declarado, con respuesta estructurada de `issues`.
- Backend: FIX APLICADO.
- `sync/push` retorna estado `INVALID` con `error_code`/`message` por item.

### P1 (necesario para consistencia offline-first)
1. Persistencia local de catalogos por version:
- `catalog_index(project_id, active_version_id, hash, updated_at)`
- `catalog_bundle(project_id, version_id, json_blob, created_at)`
2. Politica de retencion/GC segura de versiones antiguas referenciadas por actividades locales.

### P2 (UX y auditabilidad)
1. UX mobile de estado de catalogo por proyecto (actualizado/pendiente/offline).
2. Badge desktop visible: "capturada con vX" en lista/detalle/revision.

## 3. Evidencia de cambios aplicados
- `frontend_flutter/sao_windows/lib/features/events/data/events_local_repository.dart`
- `backend/app/api/v1/review.py`
- `backend/tests/test_review_observations.py`
- `.github/workflows/backend-ci.yml`
- `.github/workflows/flutter-ci.yml`
- `backend/scripts/create_operativo_demo_user.py`
- `.gitignore`
- `backend/app/api/v1/me.py`
- `backend/app/api/v1/catalog.py`
- `backend/app/api/v1/activities.py`
- `backend/app/api/v1/sync.py`
- `backend/app/services/activity_catalog_validator.py`
- `backend/app/schemas/catalog.py`
- `backend/app/schemas/sync.py`
- `backend/app/schemas/user.py`
- `backend/tests/test_auth.py`
- `backend/tests/test_catalog_versions.py`
- `backend/tests/test_sync.py`
- `backend/tests/test_activities.py`
- `frontend_flutter/sao_windows/lib/features/projects/projects_page.dart`

## 4. Criterio de verificacion recomendado
1. Backend: `pytest backend/tests/test_review_observations.py -q`.
2. Flutter mobile: `flutter test` (suite completa).
3. Verificar pipeline CI en branch de prueba con secrets de GCP.
4. Ejecutar flujo manual:
- crear evento offline,
- editar antes de sync,
- sincronizar,
- confirmar que no queda en `ERROR` por `UPDATE` prematuro.
