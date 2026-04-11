---
description: "Use when editing FastAPI backend code, Firestore services, API routers, schemas, tests, or backend documentation in backend/. Covers Python 3.11, CI-aligned commands, Firestore-first behavior, and regression expectations."
name: "SAO Backend Guidelines"
applyTo: "backend/**/*.py, backend/tests/**, backend/scripts/**"
---
# SAO Backend Guidelines

- Work in `backend/` by default. Treat `backend_python/` as legacy unless the task explicitly targets historical SQL/Alembic code.
- Match CI and local validation with Python 3.11+, `pip install -r requirements.txt`, and `pytest tests -q`.
- Keep backend changes Firestore-first. If logic appears to depend on retired SQL flows, confirm whether that path is still live before extending it.
- Preserve FastAPI layering already used in `backend/app/`: routers in `api/`, business logic in `services/`, request/response contracts in `schemas/`, shared config/auth in `core/`.
- Prefer fixing the source of incorrect API behavior instead of compensating in clients. Mobile and desktop should consume backend-derived states rather than re-deriving them.
- When changing catalog, workflow, or activity behavior, check `docs/CATALOG_CONTRACT.md`, `docs/WORKFLOW.md`, and `docs/ACTIVITY_MODEL_V1.md` before modifying DTOs or service rules.
- For test-impacting backend changes, add or update focused pytest coverage near the affected module instead of relying only on manual smoke checks.
- If docs conflict, prefer current code, `.github/workflows/backend-ci.yml`, and `STATUS.md` over older snapshots.
