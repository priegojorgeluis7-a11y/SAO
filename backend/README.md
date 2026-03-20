# SAO Backend (Firestore-only)

Backend FastAPI del Sistema de Administración Operativa (SAO) en modo 100% Firestore.

## Setup rápido

1) Crear y activar virtualenv

```bash
python -m venv venv
# Windows
venv\Scripts\activate
# Linux/macOS
source venv/bin/activate
```

2) Instalar dependencias runtime Firestore

```bash
pip install -r requirements.firestore-runtime.txt
```

3) Configurar entorno

```env
DATA_BACKEND=firestore
JWT_SECRET=your-secret
GCS_BUCKET=your-bucket
FIRESTORE_PROJECT_ID=your-gcp-project
FIRESTORE_DATABASE=(default)
SIGNUP_INVITE_CODE=your-invite-code
# ADMIN_INVITE_CODE=optional-admin-invite
```

4) Ejecutar API

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Documentación de API

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- OpenAPI: http://localhost:8000/api/v1/openapi.json

## Pruebas

La suite se ejecuta en modo firestore-only. Las pruebas SQL legacy están retiradas.

```bash
pytest tests -v
```

## Estructura

```text
backend/
├── app/
│   ├── api/
│   ├── core/
│   ├── schemas/
│   ├── services/
│   └── main.py
├── scripts/
│   ├── ensure_firestore_base_catalogs.py
│   ├── e2e_staging_flow.py
│   └── run_firestore_regression_smoke.ps1
├── tests/
└── requirements.firestore-runtime.txt
```

## Notas operativas

- Este backend ya no ejecuta migraciones Alembic.
- No requiere DATABASE_URL ni Cloud SQL para operación estándar.
- Si DATA_BACKEND != firestore, el entrypoint falla de forma explícita.
