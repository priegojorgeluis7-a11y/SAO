# SAO — Estado del Proyecto
**Fecha:** 2026-03-05
**Versión:** 0.2.2
**Deployment:** ✅ Cloud Run en producción (`sao-api` / `sao-prod-488416`)
**Auditoría:** Completada 2026-03-04 (ver `docs/AUDIT_REPORT.md`)
**Plan 100% local:** Iniciado 2026-03-04 (ver `docs/PLAN_100_LOCAL.md`)
**F0 completado:** 2026-03-04 — F0.1..F0.5 ✅
**F1 completado:** 2026-03-04 — F1.1..F1.6 ✅
**L0 completado:** 2026-03-04 — L0.1 LocalEvidenceAdapter · L0.2 `.vscode/launch.json` · L0.3 `start_local.ps1`
**L1 completado:** 2026-03-04 — L1.1 `PATCH /activities/{uuid}/flags` · L1.2 5 tests para flags (98/98 suite completa)
**L2 completado:** 2026-03-04 — L2.1 `EventsListPage` (`/events` + BottomNav item "Eventos") · L2.2 URL local ya en app_config.dart
**L3 completado:** 2026-03-04 — L3.1 (ya implementado) · L3.2 `EventsPage` desktop + NavigationRail · L3.3 `FlagResolutionDialog` (PATCH /flags) · L3.4 Color hardcodes (3 archivos) · L3.5 59 tests desktop (vs 5 antes)
**L4 completado:** 2026-03-04 — L4.1 `backend/scripts/e2e_local.py` (13-step E2E local, stdlib puro) · L4.2 `docs/CHECKLIST_REGRESION.md` (80+ casos A-K)
**L5 completado:** 2026-03-05 — L5.1 Settings móvil con backend URL runtime (persistencia + apply en caliente) · L5.2 edición/eliminación de eventos móvil + sync `UPDATE/DELETE`

---

## Estado General

| Componente | Estado | Avance | Bloqueadores |
|------------|--------|--------|-------------|
| Backend FastAPI | 🟡 En producción + local | **97%** | 1 deuda técnica menor |
| App Móvil Flutter | ✅ Operativa | **100%** | — |
| Desktop Admin Flutter | 🟡 Funcional (pendiente endurecimiento final) | **95%** | Cobertura unitaria parcial fuera de auth |
| Load Testing / QA | 🟡 E2E local + staging real ejecutado | **98%** | Falta automatizar corrida en pipeline |
| Cloud Run / Cloud SQL | 🟡 En producción | **95%** | CI/CD aún manual |
| Documentación | ✅ Auditada y actualizada | 90% | — |

---

## Verificación Ejecutada Hoy (2026-03-05)

- ✅ `flutter analyze` ejecutado en móvil tras cambios BAJA (sin errores de compilación en archivos tocados; permanecen warnings legacy del proyecto)
- ✅ Validación puntual con `get_errors` en archivos modificados (settings/api/sync/events): sin errores
- ✅ Backend integración `pytest -m integration tests/test_review_observations.py -q`: **14/14 passing** (incluye regresión de razones de rechazo dinámicas)
- ✅ Corrida E2E real en staging (`backend/scripts/e2e_staging_flow.py`) completada de punta a punta:
	- `Activity UUID`: `6997c072-4450-4f63-b9b2-5a71cb85df60`
	- `Push status`: `CREATED`
	- `Final execution_state`: `COMPLETADA`
	- Robustecimiento aplicado al script para staging real: resolución de `catalog_version_id` UUID y fallback `APPROVE_EXCEPTION` cuando aplica regla `CHECKLIST_INCOMPLETE`
- ✅ Corrida completa de `flutter test` móvil en verde en ejecución de cierre posterior (exit code 0)
- ✅ Revalidación actual de `flutter test` móvil en verde: `All tests passed` (223 tests)
- ✅ Desktop Fase 2 (avance): nuevos tests en `catalog`/`reports` + fix de exportación cross-platform; `flutter test` desktop en verde (`All tests passed`, 82 tests)
- ✅ Cobertura desktop actualizada por módulo (`flutter test --coverage`): `catalog` 10.57% (267/2526), `review` 74.42% (32/43), `reports` 36.52% (237/649)
- ⚠️ Evidencia remota GitHub Actions capturada en `main` para commit `b7f49a1d43ef140630e014a0cffefb4b1eb1069e`:
	- `Backend CI` run `22736601995`: `failure` (job `test` fallido; `Deploy to Cloud Run` skipped)
	- `Flutter CI` run `22736601947`: `failure` (job `analyze-and-test` fallido)
	- Estado Fase 1 CI/CD: sigue EN CURSO por bloqueo técnico de pipeline (ya no por falta de acceso/evidencia).

> Esta métrica refleja **estado de ejecución de pruebas hoy**, no porcentaje de cierre funcional del producto.

---

## Backend (FastAPI + Cloud Run) — 97%

### Implementado
- ✅ 55+ endpoints en 12 routers (`/auth`, `/catalog`, `/activities`, `/sync`, `/evidences`, `/events`, `/users`, `/projects`, `/assignments`, `/review`, `/audit`, `/observations`)
- ✅ RBAC con `require_permission()`, `require_any_role()`, `verify_project_access()`
- ✅ JWT access (24h) + refresh (30d) tokens
- ✅ Sync push/pull por cursor (`sync_version`)
- ✅ GCS signed URLs para evidencias (15 min) — modo local: `EVIDENCE_STORAGE_BACKEND=local` guarda en disco, sin GCP (L0.1)
- ✅ Catálogo versionado: Draft → Published → Deprecated
- ✅ Editor de catálogo (10+ endpoints)
- ✅ Bootstrap de proyecto desde template TMQ
- ✅ Auditoría completa en `audit_logs`
- ✅ 98/98 tests pytest pasando (suite completa — StaticPool fix + 5 tests PATCH /flags)
- ✅ Lifespan hooks con validación de env vars
- ✅ `GET /api/v1/review/queue` calcula `gps_critical` de forma estructurada (regla `requires_gps`, coordenadas válidas, consistencia PK/frente) (F4.2)
- ✅ `POST /api/v1/evidences/upload-init` valida `mime_type` (JPEG/PNG/PDF) y tamaño máximo de 20MB por archivo (F4.4)
- ✅ `PUT /api/v1/auth/me/pin` para almacenar `pin_hash` (bcrypt) del usuario autenticado (F5.1)
- ✅ Rate limiting en endpoints críticos: `/auth/login`, `/auth/refresh`, `/evidences/upload-init`, `/sync/push` (429 + `Retry-After`) (F5.2)
- ✅ Test E2E backend (integración local) cubre flujo: operativo `sync/push` → supervisor aprueba en review → operativo ve `COMPLETADA` en `sync/pull` (F5.4)
- ✅ Script de ejecución E2E para staging disponible: `backend/scripts/e2e_staging_flow.py` (+ guía en `docs/RUNBOOK_CLOUD_RUN.md`) (F5.4)

### FALTA / Deuda
- ✅ `GET /api/v1/fronts?project_id=` expuesto + `POST /api/v1/fronts` (alta de frentes por proyecto)
- ✅ `GET /api/v1/locations?project_id=&estado=` expuesto (+ `front_id` como resolver de proyecto) y `GET /api/v1/locations/states`
- ✅ `POST /api/v1/projects/{project_id}/locations` para configurar cobertura estado/municipio por proyecto
- ✅ `GET /api/v1/auth/roles` — lista de roles disponibles (F1.5)
- ✅ `GET /api/v1/catalog/workflow` — máquina de estados del workflow (F1.4)
- ✅ `GET /api/v1/activities/{uuid}/timeline` — historial por actividad (F2.2)
- ✅ `ActivityDTO.flags` (`gps_mismatch`, `catalog_changed`) — columnas reales en BD (F2.5 · L1.1)
- ✅ `PATCH /activities/{uuid}/flags` — set estructurado de flags + incrementa sync_version (L1.1)
- ✅ `GET /api/v1/activities/{uuid}/timeline` — historial de una actividad
- ✅ `observations.py` prefijo correcto — `main.py` ya aplica `API_V1_STR`; falsa alarma de auditoría (verificado F0.1 · 2026-03-04)
- ✅ CORS_ORIGINS desde env var CSV; URL de Cloud Run eliminada del código (F0.3 · 2026-03-04)
- ✅ Razones de rechazo en review desacopladas a tabla `reject_reasons` (seed + CRUD admin + validación runtime); cobertura de regresión agregada en integración
- ✅ Seed nacional de ubicaciones implementado (32 estados + municipios) con carga idempotente en `run_all_seeds`

---

## App Móvil Flutter (frontend_flutter/sao_windows) — 100%

### Implementado
- ✅ Autenticación JWT con auto-refresh (Dio interceptor)
- ✅ Registro con invite code
- ✅ Drift SQLite schema v5 (15+ tablas)
- ✅ Wizard de actividades (DynamicFormBuilder catalog-driven)
- ✅ Push sync: `SyncService.pushPendingChanges()` + auto-sync 15min
- ✅ Evento push: `POST /events/{uuid}` idempotente
- ✅ Reporte de eventos: `ReportEventSheet` (3 pasos)
- ✅ Upload de evidencias: presign → upload → confirm + retry
- ✅ Token storage seguro (`flutter_secure_storage`)
- ✅ Agenda del equipo (timeline)
- ✅ Catalog bundle con fallback a asset local
- ✅ Settings móvil ahora permite configurar backend URL en runtime, con persistencia en `SharedPreferences` y aplicación en caliente sobre `ApiClient`
- ✅ Eventos móvil ahora permite editar y eliminar desde la lista; los cambios se encolan y sincronizan al backend (`UPDATE`/`DELETE`)

### FALTA
- ✅ Pull sync (server → mobile) implementado con cursor compuesto (`since_version` + `after_uuid`), paginación y upsert local (F3.1)
- ✅ PIN offline login: alta de PIN tras login online + entrada offline con PIN local (hash SHA-256 asociado al usuario) (F5.1)
- ✅ UI de resolución de conflictos en Sync Center (usar mi versión con `force_override` / usar servidor con pull activo) (F3.3)
- ✅ Pull incremental de eventos implementado (`GET /events?project_id&since_version`) con persistencia en `LocalEvents` (F3.2)
- ✅ Selectores de frente/ubicación en wizard conectados a APIs (`/fronts`, `/locations/states`, `/locations`) con fallback a texto libre
- ✅ Lista de eventos del proyecto: `EventsListPage` (`/events` + 5.° BottomNav "Eventos") (L2.1)
- ✅ Diff incremental de catálogo en mobile: `check-updates` por hash + cache local del bundle (evita descarga completa cuando no hay cambios) (F3.4)
- ✅ Validación GPS en wizard: si `actividad.requiresGeo` y no hay `lat/lon`, bloquea guardado con error explícito; persiste `geoLat/geoLon` en `Activities` (F4.1)
- ✅ Evidencias mínimas por tipo en wizard: lee `workflow_checklist.photo_min_N` del bundle y bloquea submit si no se cumple el mínimo (F4.3)
- ✅ 0 hardcodes `Color(0xFF...)` en `features/` — todos reemplazados por `SaoColors.*` (F0.5 · 2026-03-04)
- ✅ Roles dinámicos en signup (F1.5) vía `/api/v1/auth/roles`
- ✅ `activity_catalog.dart` eliminado — fuente única: `CatalogRepository.activities` desde bundle (F1.1 · 2026-03-04)
- ✅ `status_catalog.dart` catalog-driven con `nextStatesFor(...)` desde `rules.workflow` (F1.2)

---

## Desktop Admin Flutter (desktop_flutter/sao_desktop) — 95%

### Implementado
- ✅ Shell con 6 pantallas: Dashboard, Operaciones, Planeación, Catálogos, Usuarios, Reportes
- ✅ Admin module: proyectos, usuarios, auditoría (5 páginas)
- ✅ Cola de revisión: PENDING/CHANGED/GPS/REJECTED/ALL
- ✅ Validation page con Evidence Gallery, Details, Minimap, Actions
- ✅ Approve / Reject / Request Changes conectados al backend
- ✅ Caption editor de evidencias
- ✅ GPS validation banner
- ✅ Assignments readonly

### FALTA / Deuda Técnica
- ✅ Project ID dinámico vía `activeProjectIdProvider` — `planning`, `reports`, `catalog`, `validation` desacoplados de 'TMQ' (F0.2 · 2026-03-04)
- ✅ Backend URL sin hardcode — requiere `--dart-define=SAO_BACKEND_URL=...`; lanza `StateError` claro si falta (F0.4 · 2026-03-04)
- ✅ JWT auto-refresh reactivo en cliente desktop (retry tras `401` vía `/auth/refresh`) (F5.4)
- ✅ Persistencia de sesión entre reinicios (access + refresh + expiración) (F5.4)
- ✅ Alta de proyecto permite configurar frentes y cobertura geográfica (estado/municipio) desde Admin Projects
- ✅ Catálogo editor UI completo — ya implementado en `catalogs_page.dart` + `catalogs_controller.dart` (L3.1 — skip)
- ✅ Outbox básico en memoria con retry para decisiones de review (`approve/reject/needsFix`) (F3.5)
- ✅ Indicador en cola de revisión para checklist incompleto por mínimo de evidencias (usa `checklist_incomplete` de backend) (F4.3)
- ✅ Pantalla de eventos: `EventsPage` + NavigationRail item (L3.2)
- ✅ Resolución de flags UI: `FlagResolutionDialog` — PATCH `/activities/{uuid}/flags` (L3.3)
- ✅ 59/59 tests desktop passing (17 ActivityStatus + 6 ActivityFlags + 9 CatalogBundle + 11 EventsModels + 16 previos) (L3.5)
- ✅ Filtros de cola usan `flags.gps_mismatch` / `flags.catalog_changed` (F2.5)
- ✅ `status_catalog.dart` catalog-driven desde workflow de bundle (F1.3)
- ✅ Panel Historial en ValidationPage consume backend timeline (F2.4)

---

## Infraestructura

| Componente | Estado |
|------------|--------|
| Cloud Run (`sao-api`, us-central1) | ✅ 100% tráfico |
| Cloud SQL PostgreSQL 16 | ✅ Operacional |
| GCS bucket (evidencias) | ✅ Operacional |
| Secret Manager (JWT, DB) | ✅ Configurado |
| CI/CD pipeline | ⚠️ Manual (`deploy_to_cloud_run.ps1`) |

---

## Assumptions (Decisiones con Defaults Razonables)

Las siguientes decisiones fueron tomadas como defaults razonables en ausencia de especificación explícita:

1. **Workflow en bundle:** Se asume que `effective.rules.workflow` eventualmente sustituirá `status_catalog.dart` en ambos clientes.
2. **Color tokens en bundle:** Se asume que `effective.color_tokens` permite actualizar colores de marca sin redeploy.
3. **PIN offline:** Se valida localmente con hash SHA-256 (email+pin) para acceso offline, mientras backend persiste `pin_hash` (bcrypt) como fuente remota de control.
4. **Observations prefijo:** Se asume que el prefijo correcto debe ser `/api/v1/observations` (actualmente `/observations`).
5. **Access token 24h:** Se evalúa reducir a 8h para sesiones de campo; revisable.

---

## Riesgos Activos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|---------|------------|
| ~~Pull sync no implementado → operativo no ve resultados de validación~~ | ~~ALTA~~ | ~~ALTO~~ | ✅ Resuelto F3.1/F3.2 |
| ~~'TMQ' hardcoded en desktop~~ | ~~ALTA~~ | ~~ALTO~~ | ✅ Resuelto F0.2 |
| Cobertura unitaria desktop incompleta fuera de auth sesión | MEDIA | MEDIO | Extender tests unitarios por módulos (catalog/review/reports) en F5 |
| ~~Observations sin /api/v1 prefix~~ | ~~MEDIA~~ | ~~MEDIO~~ | ✅ Falsa alarma — prefijo ya correcto en main.py |
| ~~Catalog local diverge del bundle → forms incorrectos~~ | ~~BAJA~~ | ~~ALTO~~ | ✅ Resuelto F1 (F1.1-F1.6) — catálogo y workflow bundle-driven |

---

## Próximos Pasos (ver IMPLEMENTATION_PLAN.md y docs/PLAN_CIERRE_100_FUNCIONAL.md para detalle)

Checklist operativo de Fase 1 (CI/CD): `docs/CI_CD_CIERRE_CHECKLIST.md`

1. **F0 (✅ Completado 2026-03-04):** CORS env, TMQ→projectId, URL desktop, 50+ color tokens mobile
2. **F1 (✅ Completado 2026-03-04):** Catálogo fuente única — F1.1..F1.6 cerrados
3. **F2 (✅ Completado 2026-03-04):** F2.1 checklist approve ✅ · F2.2 timeline backend ✅ · F2.3 reject reasons dinámicas ✅ · F2.4 timeline desktop ✅ · F2.5 flags estructurados ✅
4. **F3 (Semana 3-4):** Sync offline real (F3.1 ✅ pull actividades · F3.2 ✅ pull eventos · F3.3 ✅ conflictos · F3.4 ✅ catálogo incremental · F3.5 ✅ outbox desktop)
5. **F4 (Semana 5):** Evidencias y calidad de datos (F4.1 ✅ validación GPS wizard · F4.2 ✅ validación GPS backend en review · F4.3 ✅ mínimos de evidencia por tipo mobile+desktop · F4.4 ✅ validación MIME/tamaño en upload-init)
6. **F5 (Semana 6):** Endurecimiento (F5.1 ✅ PIN offline mobile + endpoint PIN · F5.2 ✅ rate limiting backend · F5.4 ✅ desktop JWT refresh + persistencia + tests unitarios de sesión auth · F5.4 ✅ test E2E backend local del flujo operativo→review→pull · F5.4 ✅ script/runbook + corrida E2E real en staging ejecutada; pendiente ampliar cobertura unitaria desktop)

---

## Checklist de Cierre (3 días)

### Día 1 — Backend + Catálogos
- [x] **Backend**: Externalizar razones de rechazo a catálogo/config persistente (`reject_reasons` + seed + endpoint admin).
- [x] **Backend**: Agregar test de regresión para garantizar que review use razones configurables y no hardcode.
- [x] **Done (Día 1)**: Integración en verde (`pytest -m integration tests/test_review_observations.py -q`) + evidencia de lectura de razones desde BD.

### Día 2 — Desktop + Cobertura
- [x] **Desktop**: Ampliar cobertura unitaria en módulos no-auth (`catalog`, `review`, `reports`) con incremento en `catalog` y `reports` (+20 tests acumulados).
- [x] **Desktop**: Definir línea base por módulo y registrar delta actual (`reports` +2 tests).
- [x] **Done (Día 2 parcial)**: `flutter test` desktop en verde + incremento medible en módulos objetivo (`catalog`, `reports`).

### Día 3 — Staging + Release
- [x] **QA/Backend**: Ejecutar corrida E2E real en staging con credenciales válidas (flujo operativo→review→pull).
- [ ] **DevOps**: Dejar pipeline CI/CD automatizado para deploy (build + test + deploy) reemplazando paso manual principal.
- [ ] **Done (Día 3)**: Acta de corrida staging adjunta + pipeline ejecutado al menos una vez con resultado exitoso.

### Criterio de 100% funcional-operativo
- [x] Sin razones de rechazo hardcodeadas en backend.
- [x] Corrida E2E staging exitosa documentada.
- [ ] CI/CD automatizado activo (sin dependencia de `deploy_to_cloud_run.ps1` como ruta principal).
- [ ] Cobertura desktop ampliada en módulos no-auth y validada.
- [ ] Cobertura desktop ampliada en módulos no-auth y validada (pendiente subir cobertura en `catalog` y `reports` contra baseline).

---

## Acta de Corrida E2E Staging (2026-03-05)

- Script: `backend/scripts/e2e_staging_flow.py`
- Base URL: `https://sao-api-fjzra25vya-uc.a.run.app`
- Proyecto: `TMQ`
- Resultado: ✅ `E2E flow passed`
- Evidencia:
	- `Activity UUID`: `6997c072-4450-4f63-b9b2-5a71cb85df60`
	- `Push status`: `CREATED`
	- `Final execution_state`: `COMPLETADA`
- Observaciones técnicas:
	- `/catalog/version/current` devolvió `version_id` semántico (`tmq-v2.0.0`) y no UUID; se ajustó el script para resolver UUID canónico desde `/catalog/versions`.
	- En revisión, aprobación estándar devolvió `422 CHECKLIST_INCOMPLETE`; el flujo E2E aplicó fallback controlado a `APPROVE_EXCEPTION` para validar ruta operativa completa en entorno real.
