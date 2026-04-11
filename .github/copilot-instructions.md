# Project Guidelines

## Architecture
- This repository has three active codebases: `backend/` (FastAPI API), `frontend_flutter/sao_windows/` (Flutter field app), and `desktop_flutter/sao_desktop/` (Flutter admin app). Treat mobile and desktop as separate clients; do not assume shared widgets, routing, or data models.
- Prefer the current workspace docs before historical notes. Start with `docs/README.md` as the documentation index, `STATUS.md` for the latest operational state, `ARCHITECTURE.md` for system structure, and `docs/DOCUMENTO_MAESTRO_SISTEMA.md` for high-level product context.
- `backend_python/` is legacy/historical unless the task explicitly targets it. Default backend work to `backend/`.

## Build and Test
- Backend requires Python 3.11+. For full local development and tests in `backend/`, use `pip install -r requirements.txt`, run `pytest tests -q`, and start the API with `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`.
- Backend runtime is Firestore-only. `DATA_BACKEND=firestore` is the supported mode, and startup validation requires `FIRESTORE_PROJECT_ID`; use `requirements.firestore-runtime.txt` only for runtime-only/backend image scenarios while CI installs `requirements.txt`.
- Mobile app commands in `frontend_flutter/sao_windows/`: `flutter pub get`, `flutter analyze`, `flutter test`, and `dart run build_runner build --delete-conflicting-outputs` when Drift or other generated code is affected.
- Desktop app commands in `desktop_flutter/sao_desktop/`: `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter test`, and `flutter run -d macos --dart-define=SAO_BACKEND_URL=<url>`.

## Conventions
- SAO is catalog-driven. Do not hardcode forms, workflow rules, permissions, or activity behavior when a catalog-backed path already exists. Check `docs/CATALOG_CONTRACT.md`, `docs/WORKFLOW.md`, and `docs/ACTIVITY_MODEL_V1.md` before changing domain logic.
- Frontend clients should trust backend-derived states instead of recomputing them locally. Follow `docs/STATE_BEST_PRACTICES.md` for status/review/sync handling.
- For Flutter UI work, use the design system and semantic tokens from `docs/DESIGN_SYSTEM.md` and `docs/DESIGN_TOKENS.md`. Avoid direct color literals and, on desktop, avoid raw neutral surfaces when a theme-aware `SaoColors` helper exists.
- When adding or editing documentation, link to canonical docs instead of duplicating existing explanations. Use `docs/TEMPLATE_DOC.md` for new docs.

## Pitfalls
- The desktop client rejects `localhost` and `127.0.0.1` for `SAO_BACKEND_URL`; use the Cloud Run URL or a LAN IP.
- On macOS, Flutter desktop builds inside iCloud-synced `Documents/` can fail codesign. If build issues look environment-specific, reproduce from a temporary directory outside `Documents/`.
- Some repo docs and component READMEs are dated snapshots. If a document conflicts with current code or CI, prefer the live code, current workflows in `.github/workflows/`, and `STATUS.md`.