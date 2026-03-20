# Changelog

All notable changes to this project will be documented in this file.

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
