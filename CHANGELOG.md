# Changelog

All notable changes to this project will be documented in this file.

## [9.0.0] - 2026-06-25

### Added

- **Optimización de costos Cloud Run/Firestore**
  - Índices de Firestore actualizados para mejor rendimiento
  - Queries optimizadas en reports.py y assignments.py
  - Módulo de caché implementado para reducir lecturas

- **Compilaciones actualizadas**
  - Android AAB (56.8 MB) - Google Play Store
  - Android APK (35.7 MB) - Pruebas
  - iOS (30.4 MB) - con dSYMs configurados
  - macOS Desktop (67.2 MB)

- **Mejoras iOS**
  - Podfile actualizado para generar dSYMs en todos los pods
  - Configuración de Debug Information Format para release

### Fixed

- **Errores menores de compilación y warnings**

---

## [1.0.10] - 2026-05-22

### Fixed

- **Incidencias de campo sin persistencia — App Móvil** (`home_page.dart` → `_reportIncident`)
  Las incidencias rápidas «Clima», «Acceso denegado» y «Riesgo» solo actualizaban el estado visual en memoria; al recargar la app o tras un pull de sync el registro se perdía. Ahora se crea un `EventDTO` y se persiste en la tabla local `local_events` vía `EventsLocalRepository.saveEvent()`, que a su vez encola la incidencia en `sync_queue` con `entity=EVENT` para su envío automático al backend (`POST /events`). El estado visual de la actividad continúa reseteándose a `pendiente`.
  Mapeo de tipos: «Acceso denegado» → `BLOQUEO`; «Clima» / «Riesgo» → `OTRO`.
  Severidad: «Riesgo» → `HIGH`; resto → `MEDIUM`.

- **Badge de notificaciones omitía alertas locales — App Móvil** (`home_page.dart:3138`)
  El indicador visual de la campana en el AppBar evaluaba solo `backendUnreadCount` (notificaciones remotas sin leer). La variable `totalBellCount = _notificationCount + backendUnreadCount` existía y se calculaba correctamente pero se descartaba. Ahora la condición del badge usa `totalBellCount`, por lo que actividades rechazadas, vencidas y errores de sync locales también incrementan el contador.

- **Sheet de estado de sync mostraba «Pendientes: N/A» hardcodeado — App Móvil** (`home_page.dart:2871`)
  El panel de «Estado de sincronización» que aparece al tocar el ícono de nube siempre mostraba `Pendientes: N/A`. Ahora usa un `FutureBuilder` con `syncRepositoryProvider.countPendingItems()` para mostrar el conteo real de ítems en los estados `PENDING`, `IN_PROGRESS` o `ERROR` de la tabla `sync_queue`.

- **Métricas de progreso de secciones siempre en cero — App Móvil** (`home_task_sections.dart:188`)
  `TaskSectionMetrics.completedCount` estaba hardcodeado a `0` con un TODO. Ahora cuenta las actividades cuyo `executionState == ExecutionState.terminada` dentro de cada sección, lo que permite que los indicadores de progreso del Home reflejen el avance real.

### Removed

- **`AssignmentSyncServiceNoOp` eliminado** (`pending_sync_services.dart`)
  Clase muerta con un TODO engañoso (`// TODO: Integrar sync de assignments cuando exista API/queue dedicada.`). El proveedor `assignmentSyncServiceProvider` ya apuntaba a `AssignmentSyncServiceImpl` (la implementación real con retry). La clase `NoOp` nunca fue instanciada en producción.

- **`_hasUnresolvedCatalogDecision` eliminado** (`desktop_flutter/…/activity_details_panel_pro.dart`)
  Método declarado pero nunca invocado (`unused_element` confirmado por `flutter analyze`). Fue desacoplado en la corrección de `_hasCatalogGap` (v1.0.9) pero nunca eliminado. Se remueve para evitar confusión y falsos retornos si se volvía a referenciar.

### Added

- **Script de backfill `review_decision`** (`backend/scripts/backfill_completada_review_decision.py`)
  Localiza actividades con `execution_state=COMPLETADA` y `review_decision` nulo/vacío en Firestore (documentos corruptos por la condición de carrera corregida en v1.0.9) y les asigna `review_decision=APPROVED` + `review_state=APPROVED`. Soporta `--dry-run` para previsualizar y `--project` para filtrar por proyecto.
  Uso: `FIRESTORE_PROJECT_ID=sao-prod-488416 JWT_SECRET=<secret> DATA_BACKEND=firestore python backend/scripts/backfill_completada_review_decision.py --dry-run`

---

## [1.0.9] - 2026-05-22

### Fixed

- **Dedup actividades multiresponsables — Backend (series de 4 fixes)**
  - `dashboard_kpis.py`, `completed_activities.py`, `reports.py`: deduplica por `activity_group_id` antes de calcular métricas/totales; una actividad con N responsables ahora cuenta como 1 en KPIs, expediente y reportes.
  - `reports.py`, `assignments.py`, `completed_activities.py`: mismo dedup aplicado en `/reports/activities` y `/assignments`.
  - `activities.py`: dedup en `/activities` (fuente principal del dashboard) respetando modo sin-filtros personales para no romper sincronización móvil.
  - `completed_activities.py`, `dashboard_kpis.py`, `reports.py`: dedup legacy por clave compuesta (`project_id + activity_type_code + assignment_start_at + assignment_end_at + created_by_user_id + front_id + pk_start`) cuando `activity_group_id` está ausente.
  - `backend/scripts/backfill_activity_group_ids.py` (nuevo): script de migración que asigna `activity_group_id` en Firestore a grupos legacy con más de 1 documento.

- **Fix evidencias en revisión** (`backend/app/api/v1/review.py`)  
  Evidencias guardadas con `gcs_path` / `storage_path` / `pending_object_path` en lugar de `object_path` eran reportadas incorrectamente como PENDING en el panel de revisión ("La evidencia aún no está disponible en el servidor"). Ahora usa la misma lógica de resolución de ruta que el endpoint de descarga (`_resolve_evidence_object_path`).

- **Auto-clear `catalog_changed` al aprobar último candidato** (`backend/app/api/v1/catalog_candidates.py`, `activity_details_panel_pro.dart`)  
  Cuando se aprueba el último candidato de un grupo, el backend limpia automáticamente `flags.catalog_changed`. En el cliente desktop, `_hasCatalogGap` ahora usa únicamente `activity.flags.catalogChanged` (fuente de verdad del backend) en lugar de llamar también a `_hasUnresolvedCatalogDecision`, que generaba falsos positivos cuando el bundle aún no había cargado.

- **Expediente digital — overflow en chips** (`digital_records_page.dart`)  
  `_FollowUpChip` y `_StatPill` desbordaban visualmente cuando el espacio disponible era reducido. Se envuelve el `Text` en `Flexible` con `overflow: ellipsis`.

- **Expediente digital — conteo de reportes** (`digital_records_page.dart`)  
  El contador reflejaba cuántas veces se había regenerado el reporte en lugar de `1`. `_summaryDocumentCount` y `_documentCountForDetail` ahora devuelven máximo `1` (cada actividad tiene un único reporte activo).

### Added

- **Tests dedup multiresponsables** (`backend/tests/test_activities_dedup.py`)  
  261 líneas, 5 casos: grupo de 3 responsables → devuelve 1; filtro `assigned_to_user_id` → sin dedup (modo móvil); filtro `updated_since_sync_version` → sin dedup (sync incremental); actividades individuales sin `activity_group_id`; mix grupo + individuales.

### Chore

- **Desktop v1.0.2+3** (`desktop_flutter/sao_desktop/pubspec.yaml`): bump de versión.
- **Scripts de build Windows** (`build_windows_prod.ps1`, `build_and_sign_windows.ps1`, `build_sign_and_package_windows.ps1`): se agrega parámetro `BackendUrl` y se pasa `--dart-define=SAO_BACKEND_URL` en todos los scripts de build/firma/empaquetado.
- **Instalador Windows v1.0.2** (`sao_desktop_instalador.iss`, `crear_instalador_sao.ps1`): versión 1.0.1 → 1.0.2; `--dart-define=SAO_BACKEND_URL` añadido al comando flutter build; README con instrucciones completas para otra PC (Git, Flutter, VS2022, Inno Setup 6).
- **Entrega macOS**: zip renombrado a `SAO-Desktop-macOS-1.0.2.zip`.

---

## [1.0.8] - 2026-05-06

Versión consolidada que incluye todos los cambios de 1.0.7 y 1.0.8.

### Added
- **Co-responsable en actividades**: el usuario OPERATIVO puede agregar a otro miembro del proyecto como co-responsable de una actividad desde la pantalla principal (app móvil).
- **Notificaciones push FCM**: integración de Firebase Cloud Messaging para enviar notificaciones remotas a dispositivos registrados.
- **Instalador Windows**: script `build_installer.ps1` con Inno Setup para generar el `.exe` del cliente escritorio con ícono oficial SAO.
- **Página de administración de issues de sync** (`sync_issues_page.dart`) en el cliente escritorio.
- **Endpoint público `/support`**: página de soporte accesible sin autenticación en el backend.
- **Endpoint `/privacy-policy`** disponible públicamente.

### Changed
- Terminología **Frente → Segmento** en reportes PDF del cliente escritorio (`toSegmentName()`, aplica a todos los proyectos).
- `DELETE /activities/{uuid}` cambiado a **hard-delete permanente** en Firestore (con audit log previo).
- `birth_date` en el registro de usuario pasa a ser **opcional** (Guía 5.1.1v App Store).
- AAB Android reducido de **137.9 MB → 52.9 MB** habilitando minify, shrinkResources y obfuscate.

### Fixed
- Corrección de overflow visual en reportes escritorio (TopBar, ActivityTray, MiniDocPreview).
- Sincronización: tolerancia a `pk_end < pk_start` y UUIDs inválidos en `participant_user_ids`.
- OPERATIVO ahora puede listar sus actividades aprobadas para generación de PDF.
- Resolución correcta del nombre del resultado desde `wizard_payload` en `/completed-activities` y `/reports/activities`.

---

## [1.0.6] - 2026-04-28

### Added
- **Crear asignación propia**: OPERATIVO puede crear asignaciones para sí mismo sin necesitar a un despachador.
- **Eliminar actividad**: cualquier usuario con el rol adecuado puede eliminar actividades, con validación de permisos por rol.
- **Sincronización con Google Calendar** vía `url_launcher` (escritorio + móvil).
- **Caché offline de catálogos geográficos**: municipios y frentes/segmentos disponibles sin conexión.

### Changed
- COORD obtiene alcance global de proyectos (equivalente a SUPERVISOR).
- OPERATIVO ve a todos los miembros del proyecto como candidatos de transferencia de responsabilidad.

### Fixed
- Remoción del plugin `device_calendar` que causaba crash al abrir la app móvil.
- Corrección de llave foránea al eliminar evidencias en base de datos local.
- Filtro de asignables: ADMIN excluido de roles asignables; OPERATIVO filtrado por membresía de proyecto.
- Pantalla gris en cliente web (soporte Drift para base de datos web).
- Reportes: resolución correcta del campo `frente` en actividades completadas.

---

## [0.2.4] - 2026-03-09
### Changed
- Closed CI/CD Phase 1 for backend with complete GitHub Actions pipeline in green (`test + build + deploy + smoke`).
- Standardized deployment authentication via Workload Identity Federation (WIF) in backend workflow.
- Consolidated project documentation governance with:
	- `docs/DOCUMENTO_MAESTRO_EJECUCION_SAO.md`
	- `docs/DOCUMENTO_MAESTRO_SISTEMA.md`
	- `docs/README.md` (documentation hub)
	- `docs/historico/README.md` + historical folder split (`auditorias/`, `planes/`).

### Verified
- Backend CI run: `22880086051` -> `success`.
- Deploy to Cloud Run: `success`.
- Smoke test `/health`: `success`.

### Notes
- Remaining technical closure item: increase desktop non-auth coverage (`catalog`, `reports`) against baseline targets.

## [0.2.3] - 2026-03-05
### Verified
- Re-ran real Cloud Run E2E (`backend/scripts/e2e_staging_flow.py`) with assignment users:
	- `operativo.asignaciones@sao.mx`
	- `admin.asignaciones@sao.mx`
- Evidence: `Activity UUID=8124c360-283e-48f1-949c-782ff21f32cd`, `Push status=CREATED`, `Final execution_state=COMPLETADA`.
- Debug snapshot: `baseline current_version=2`, `catalog_version_id=13194331-c6ce-4b81-8c42-c66d98e9df17`, `timestamp_utc=2026-03-05T23:05:49.835800+00:00`.

## [0.2.2] - 2026-03-05
### Changed
- Completed real staging E2E execution using `backend/scripts/e2e_staging_flow.py` against Cloud Run (`https://sao-api-fjzra25vya-uc.a.run.app`) for project `TMQ`.
- Hardened staging E2E script to resolve canonical UUID `catalog_version_id` via `/api/v1/catalog/versions` when `/api/v1/catalog/version/current` returns semantic IDs (for example `tmq-v2.0.0`).
- Added controlled fallback in review step: when `APPROVE` returns `422 CHECKLIST_INCOMPLETE`, script retries with `APPROVE_EXCEPTION` to validate end-to-end operability in real environments.
- Fixed desktop reporting export for Windows paths in `ReportExportService` by replacing manual `split('/')` file extraction with cross-platform `path.basename(...)`.
- Fixed incorrect relative import in `report_export_service.dart` uncovered during reporting test execution.

### Added
- Added desktop reporting unit tests:
	- `test/features/reporting/report_context_test.dart`
	- `test/features/reporting/report_export_service_test.dart`
- Added additional desktop unit tests for coverage hardening:
	- `test/features/reporting/report_entities_test.dart`
	- Expanded `test/catalog/status_catalog_test.dart` with transition/permission/helper scenarios.
	- `test/catalog/roles_catalog_test.dart`
	- Expanded `test/features/catalogs/catalog_bundle_models_test.dart` with workflow/topic-policy scenarios.
	- `test/features/reports/reports_provider_test.dart` (model mapping + PDF generation with mocked `path_provider`).

### Verified
- Staging E2E result: `E2E flow passed`.
- Evidence: `Activity UUID=6997c072-4450-4f63-b9b2-5a71cb85df60`, `Push status=CREATED`, `Final execution_state=COMPLETADA`.
- Integration regression suite for review observations remains green: `pytest -m integration tests/test_review_observations.py -q` -> `14 passed`.
- Desktop suite remains green after reporting/catalog changes: `flutter test` -> `All tests passed` (82 tests).
- Desktop module coverage improved (`flutter test --coverage`):
	- `catalog`: 10.57% (267/2526)
	- `review`: 74.42% (32/43)
	- `reports`: 36.52% (237/649)

### Notes
- Documentation and audit trail updated in `STATUS.md`, `docs/AUDIT_REPORT.md`, and `docs/RUNBOOK_E2E_STAGING.md`.

## [0.1.1] - 2026-03-02
### Added
- Tracked remaining source folders in workspace snapshot (backend, backend_python, desktop_flutter, frontend_flutter, load_tests, and docs set).
- Excluded local environment folders `.vs/` and `.claude/` from version control.

### Notes
- This release finalizes the initial full-code repository import after baseline `v0.1.0`.

## [0.1.0] - 2026-03-02
### Added
- Initial Git version-control baseline for workspace `d:/SAO`.
- Root versioning files: `VERSION`, `CHANGELOG.md`, `.gitignore`.
- Technical documentation for current app behavior in `docs/WIZARD_REGISTRO_Y_CATALOGOS_ACTUALES.md`.

### Notes
- This release captures the current integrated state (wizard flow, catalog sync, and production stabilization changes).
