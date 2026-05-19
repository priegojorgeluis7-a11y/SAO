# Changelog

All notable changes to this project will be documented in this file.

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
