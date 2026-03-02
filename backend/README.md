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
```

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
