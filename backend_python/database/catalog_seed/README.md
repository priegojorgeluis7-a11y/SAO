# SAO Catalog DB — Migrations + Seed

Este modulo inicializa el catalogo institucional (proyectos, actividades, subcategorias, propositos, temas, relaciones, resultados, asistentes) con versionado y soporte de overrides por proyecto.

Incluye:

- Alembic scaffold (alembic.ini, env.py, script.py.mako)
- Migrations:
  - 001_create_catalog_schema.py
  - 002_indexes_constraints.py
- Seed idempotente: seed.sql
- Importador JSON transaccional con validacion FK: import_catalog.py
- Seeds JSON en catalog_seed/ (incluye topics.json con type/description nullable)

Nota: topics.type y topics.description permiten NULL para dos temas presentes en relaciones pero no claramente definidos en CAT_TEMAS: "Actores locales" y "Comunicacion social".

## 1) Requisitos

- Python 3.10+
- PostgreSQL 14+
- Variables de entorno:
  - DATABASE_URL (formato SQLAlchemy)
    - Ejemplo:
      - postgresql+psycopg2://user:pass@localhost:5432/sao
  - DATABASE_URL_PSQL (formato Postgres para psql)
    - Ejemplo:
      - postgresql://user:pass@localhost:5432/sao

Instala dependencias (si aplica):

```bash
pip install -r requirements.txt
```

## 2) Ejecutar migrations (Alembic)

Desde la carpeta del backend:

```bash
export DATABASE_URL="postgresql+psycopg2://user:pass@localhost:5432/sao"
alembic upgrade head
```

Verifica estado:

```bash
alembic current
alembic history
```

## 3) Cargar datos del catalogo

### Opcion A — Seed SQL (idempotente)

```bash
psql "$DATABASE_URL_PSQL" -f database/seed.sql
```

Puedes correrlo multiples veces sin duplicar.

### Opcion B — Importador JSON (recomendado para CI)

```bash
python database/import_catalog.py --database-url "$DATABASE_URL" --version-id "v1_2026_02_18"
```

El importador:

- inserta en orden seguro para FKs
- valida integridad
- usa una transaccion (rollback si falla)

## 4) Smoke test recomendado (manual)

Ejecuta estas consultas para confirmar que cargo:

```bash
psql "$DATABASE_URL_PSQL" -f database/catalog_seed/smoke_test.sql
```

```sql
-- Conteos basicos
select count(*) from cat_projects;
select count(*) from cat_activities;
select count(*) from cat_subcategories;
select count(*) from cat_purposes;
select count(*) from cat_topics;
select count(*) from rel_activity_topics;
select count(*) from cat_results;
select count(*) from cat_attendees;

-- Huerfanos (deberia ser 0)
select count(*) from cat_subcategories s
left join cat_activities a on a.activity_id = s.activity_id
where a.activity_id is null;

select count(*) from cat_purposes p
left join cat_activities a on a.activity_id = p.activity_id
where a.activity_id is null;

select count(*) from cat_purposes p
left join cat_subcategories s on s.subcategory_id = p.subcategory_id
where p.subcategory_id is not null and s.subcategory_id is null;

select count(*) from rel_activity_topics r
left join cat_activities a on a.activity_id = r.activity_id
where a.activity_id is null;

select count(*) from rel_activity_topics r
left join cat_topics t on t.topic_id = r.topic_id
where t.topic_id is null;

-- Version actual (deberia ser 1)
select count(*) from catalog_version where is_current = true;

-- Duplicados logicos (deberia ser 0)
select count(*) from (
  select activity_id, topic_id
  from rel_activity_topics
  group by activity_id, topic_id
  having count(*) > 1
) dup;

-- Subcategoria debe corresponder a la misma actividad
select count(*) from cat_purposes p
join cat_subcategories s on s.subcategory_id = p.subcategory_id
where p.subcategory_id is not null and p.activity_id <> s.activity_id;
```

## 5) Reset seguro (solo DEV)

Solo para desarrollo local.

```bash
alembic downgrade base
alembic upgrade head
```

Luego recarga seed (SQL o JSON).

Si prefieres un comando listo:

```bash
powershell -ExecutionPolicy Bypass -File database/catalog_seed/reset_dev.ps1 -DatabaseUrl "$DATABASE_URL"
```

## 6) Siguiente paso del roadmap

1) FastAPI:
- modelos SQLAlchemy/Pydantic
- endpoints CRUD admin (desktop)
- endpoint /catalog/effective?project_id=TMQ (catalogo base + overrides)

2) Flutter/Drift:
- espejo local del catalogo efectivo (offline-first)
- sincronizacion por catalog_version

## Dos mejoras rapidas que te recomiendo anadir (muy pequenas, mucho valor)

### A) Health check SQL

Incluido: smoke_test.sql con los queries de huerfanos + conteos.

### B) Comando unico de bootstrap

Incluido: bootstrap_catalog.ps1 que hace:

- alembic upgrade head
- python database/import_catalog.py ...
