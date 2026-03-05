# SAO Backend

FastAPI backend para el Sistema de Administración Operativa (SAO).

## 🚀 Setup

### 1. Create virtualenv

```bash
python -m venv venv
```

**Activar virtualenv:**
- Windows: `venv\Scripts\activate`
- Linux/Mac: `source venv/bin/activate`

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure environment

```bash
cp .env.example .env
```

Editar `.env` con tu configuración de base de datos:
```env
DATABASE_URL=postgresql://user:password@localhost:5432/sao_db
JWT_SECRET=your-secret-key
SIGNUP_INVITE_CODE=your-invite-code
# ADMIN_INVITE_CODE=optional-admin-invite-code
```

Variables de signup:
- `SIGNUP_INVITE_CODE`: requerida para crear cuentas no ADMIN vía `/api/v1/auth/signup`.
- `ADMIN_INVITE_CODE`: opcional. Si no está definida, el signup de `ADMIN` se rechaza con `403`.

### 4. Setup Database

**Crear base de datos PostgreSQL:**
```sql
CREATE DATABASE sao_db;
CREATE USER sao WITH PASSWORD 'sao123';
GRANT ALL PRIVILEGES ON DATABASE sao_db TO sao;
```

**Run migrations + seeds (recommended):**
```bash
DATABASE_URL=postgresql://user:password@localhost:5432/sao_db \
python scripts/run_migrations_and_seed.py
```

**Run migrations only:**
```bash
alembic upgrade head
```

### 5. Run Seeds (Initial Data)

```bash
python -m app.seeds.run_seeds
```

Opcional: para evitar descarga remota del catálogo nacional de estados/municipios,
define `MX_LOCATIONS_DATA_FILE` apuntando a un JSON local (mismo formato del origen público).

**Cloud Run Job example:**
```bash
gcloud run jobs create sao-migrations \
	--image gcr.io/PROJECT_ID/sao-backend:latest \
	--command python \
	--args scripts/run_migrations_and_seed.py \
	--set-env-vars DATABASE_URL=postgresql://USER:PASSWORD@/DB?host=/cloudsql/INSTANCE \
	--region REGION

gcloud run jobs execute sao-migrations --region REGION
```

### 6. Start server

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 6.1 Local-only mode (SQLite, no Cloud SQL)

Para trabajar 100% local (sin tocar servidores reales):

```powershell
cd backend
./scripts/start_local_sqlite.ps1
```

Esto crea/usa `local_dev.db`, corre seeds base y levanta la API en `127.0.0.1:8000`.
Nota: el seed de catálogo efectivo se omite en este modo con `SAO_SKIP_EFFECTIVE_CATALOG_SEED=1`.

### 6.2 Migrate to real Cloud SQL (one command)

Cuando termines desarrollo local y quieras aplicar migraciones/seeds en Cloud SQL:

```powershell
cd backend
./scripts/migrate_to_cloudsql.ps1
```

Este script:
- lee `DATABASE_URL`, `JWT_SECRET`, `GCS_BUCKET` desde Secret Manager,
- levanta `cloud-sql-proxy` temporal,
- ejecuta migraciones + seeds,
- y cierra el proxy al finalizar.

Opciones útiles:

```powershell
# Solo migraciones (sin seeds)
./scripts/migrate_to_cloudsql.ps1 -RunSeeds $false

# Omitir seed efectivo (si aplica en un entorno específico)
./scripts/migrate_to_cloudsql.ps1 -SkipEffectiveCatalogSeed $true
```

## 📚 API Documentation

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/api/v1/openapi.json

## 🧪 Testing

```bash
pytest tests/ -v
pytest tests/ --cov=app  # With coverage
```

## 🧹 Convenciones de Código (2026-03)

### API / Routers

- Mantener anotaciones explícitas de retorno en endpoints (`-> TokenResponse`, etc.).
- Re-lanzar `HTTPException` cuando viene de servicios/deps; no degradar errores conocidos a `500` genérico.
- Usar `UserStatus.ACTIVE` para validación de estado de usuario (evitar comparar strings como `"active"`).

### Schemas (Pydantic)

- Preferir tipado moderno (`str | None`) sobre `Optional[str]`.
- Validar estado de ejecución y rango PK (`pk_end >= pk_start`) en payloads de actividad/sync.
- Mantener compatibilidad de entrada cuando aplique usando aliases (`camelCase` y `snake_case`).

### Servicios / SQLAlchemy

- Para booleanos en filtros, usar `.is_(True)` / `.is_(False)` en lugar de `== True/False`.
- Evitar duplicación de lógica de serialización/normalización; centralizar helpers dentro del servicio.

### Scripts operativos

- Reutilizar utilidades compartidas en `scripts/_script_utils.py` para:
	- logging,
	- lectura de `DATABASE_URL`,
	- setup de `sys.path`,
	- configuración de Alembic,
	- ejecución de seeds comunes.
- Scripts que aplican esta convención: `run_migrations_and_seed.py`, `reset_and_migrate.py`, `fix_prod_migrations.py`.

## 📦 Project Structure

```
backend/
├── alembic/               # Database migrations
├── app/
│   ├── api/              # API endpoints
│   ├── core/             # Config, security, database
│   ├── models/           # SQLAlchemy models
│   ├── schemas/          # Pydantic schemas
│   ├── services/         # Business logic
│   └── main.py           # FastAPI app
├── tests/                # Unit tests
└── requirements.txt      # Dependencies
```

## 🔑 Default Credentials

After running seeds:
```
Email: admin@sao.mx
Password: admin123
```

## 📖 Documentation

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md)

---

**Version:** 1.0.0  
**Last Updated:** 2026-03-01
