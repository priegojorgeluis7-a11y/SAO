# SAO - Estado del Proyecto

**Fecha:** 03 de marzo de 2026
**Versión:** 1.0.0-rc1
**Deployment:** ✅ Cloud Run en producción (`sao-api` / `sao-prod-488416`)

---

## Estado General

| Componente | Estado | Avance |
|------------|--------|--------|
| Backend FastAPI | 🟡 Funcional pero con errores entre microservicios | 80% |
| App Móvil Flutter | 🟡 Funcional (falta sync push + eventos) | ~90% |
| Desktop Admin Flutter | 🔴 Prototipo parcial | ~20% |
| Load Testing / QA | ✅ Validado | 100% |
| Cloud Run / Cloud SQL | ✅ En producción | 100% | *Revisar catalogos con error 500

---

## Backend (FastAPI + Cloud Run) ✅ 100%

### Hardening técnico (2026-03-01)
- ✅ Limpieza y refactor en `api/v1`, `services`, `schemas` y `scripts` con foco en consistencia y bajo riesgo.
- ✅ Scripts operativos unificados con utilidades compartidas en `backend/scripts/_script_utils.py`.
- ✅ Migración de FastAPI `@app.on_event("startup")` a `lifespan` (elimina warning deprecado propio).
- ✅ Reemplazo de `datetime.utcnow` por timestamps UTC timezone-aware en `app/models/base.py`.
- ✅ Validación backend focalizada: `pytest tests/test_auth.py tests/test_sync.py -q` → **20 passed**.
- ✅ Upgrade controlado de dependencias web: `fastapi 0.135.1`, `starlette 0.52.1`, `httpx 0.28.1`, `python-multipart 0.0.22`.
- ✅ Revalidación posterior a upgrade: `pytest tests/test_auth.py tests/test_sync.py -q` → **20 passed**.
- ✅ Warnings externos críticos observados previamente (deprecaciones `on_event`, `httpx app shortcut`, `asyncio.iscoroutinefunction`) quedaron mitigados en las corridas actuales.
- ✅ Limpieza adicional de tests: reemplazo de `datetime.utcnow()` por UTC timezone-aware en `tests/test_catalog_effective.py` → **8 passed** sin warnings en esa suite.
- ✅ Verificación global de regresión: `pytest tests -q` → **50 passed** en la corrida completa actual.
- ✅ Seed de catálogo ejecutado en modo forzado: `python -m app.seeds.catalog_tmq_v1 --force-update`.
- ✅ Smoke funcional de catálogo tras seed:
    - `GET /api/v1/catalog/latest?project_id=TMQ` → `200` (version `1.0.0`, `13` form fields)
    - `GET /api/v1/catalog/check-updates?project_id=TMQ` → `200` (`update_available=true`, hash actualizado)
- ✅ Limpieza de código muerto/malas prácticas en backend:
    - `backend/main.py` legado reemplazado por shim de compatibilidad hacia `app.main`.
    - eliminación de bloques `finally: pass` sin efecto en fixtures de tests.
    - normalización de documentación técnica en endpoint de publicación de catálogo.
    - validación posterior: `pytest tests/test_auth.py tests/test_catalog_effective.py tests/test_sync.py -q` → **28 passed**.

### Endpoints (21 total)
- **Auth** (3): `/auth/login`, `/auth/refresh`, `/auth/me`
- **Catalog** (8): latest, check-updates, versions CRUD, effective, diff
- **Activities** (5): CRUD + soft delete por UUID
- **Sync** (2): `/sync/push`, `/sync/pull`
- **Evidence** (3): init-upload, complete-upload, download-url (GCS signed URLs)
- **Health** (1): `/health` con verificación DB

### Infraestructura
- Cloud Run: servicio `sao-api`, región `us-central1`, 100% tráfico
- Cloud SQL: PostgreSQL 16, conexión por unix socket
- Secrets: JWT secret + DATABASE_URL en Secret Manager
- Deploy: `deploy_to_cloud_run.ps1` con gate de smoke test automático
- Smoke test post-deploy: `backend/scripts/smoke_test_prod.ps1`

### Código
- ~4,500 LOC Python (50+ archivos)
- 16+ modelos SQLAlchemy (User, Role, Project, Activity, Evidence, Catalog…)
- 6 migraciones Alembic aplicadas
- 2 seeds: `initial_data.py` (roles/users/TMQ) + `catalog_tmq_v1.py` (v1.0.0)
- 50 tests pytest pasando (~80% cobertura en features core)

---

## App Móvil Flutter (~90%)

### Hardening frontend (2026-03-02)
- ✅ Refactor de compatibilidad en módulo de evidencias (`camera_capture_service`, `gps_tagging_service`, `image_compression_service`) para eliminar errores de compilación y drift de APIs.
- ✅ `CapturedEvidence` y `GpsLocation` normalizados con campos epoch (`capturedAtEpochMs`, `timestampEpochMs`) manteniendo getters `DateTime` para compatibilidad.
- ✅ Correcciones de contratos y tipografía/tema usados por UI de evidencias (`titleMedium`, `borderLight`) y mejora de imports en providers.
- ✅ Dependencias de evidencias alineadas en Flutter (`camera`, `geolocator`, `image`).
- ✅ Limpieza de tests de evidencias (parámetros actualizados, comentarios inválidos corregidos, expectativas de widgets ajustadas a la UI actual).
- ✅ Limpieza automática de estilo con `dart fix` en `lib/features/evidence` y `test/features/evidence` (102 fixes aplicados) con corrección posterior de reasignaciones `const`.
- ✅ Limpieza global incremental en frontend (`flutter analyze` proyecto completo):
    - resolución de errores de compilación en wizard/auth/catalog/sync (tipado API, imports, Drift, provider).
    - `dart fix --apply lib` ejecutado (192 fixes en 50 archivos).
    - reducción de issues de analyzer de **415 → 89** (sin diagnósticos `error -` ni `warning -`; restantes son infos de estilo/deprecación).
- ✅ Validación focalizada:
    - `flutter analyze lib/features/evidence test/features/evidence` → **No issues found**.
    - `flutter test test/features/evidence/widgets/evidence_widgets_test.dart` → **24 passed**.
    - regresión tras limpieza global: `flutter test test/features/evidence/widgets/evidence_widgets_test.dart` → **24 passed**.

### Completo
- **Auth**: HTTP layer (Dio + JWT auto-refresh) + Repository Riverpod + Login UI
- **Catalog sync**: API repository + Drift persistence + CatalogSyncService (check→fetch→persist)
- **DynamicFormBuilder**: 7 tipos de campo, validaciones, 25 tests unitarios
- **Evidence capture**: cámara, GPS, compresión, upload a GCS, cola offline, 210+ tests
- **Home/Activities**: wizard registro, swipe states (PENDIENTE→EN_CURSO→REVISION→COMPLETADA)
- **Agenda coordinador**: calendario semanal, timeline, detección de conflictos
- **Settings**: debug panel con 4 smoke tests integrados

### Completado (2026-03-02)
- ✅ Sync push completo (SyncService + AutoSyncService + SyncCenterPage integrado)
- ✅ Módulo Eventos Mobile (LocalEvents Drift v5, EventsApiRepository, EventsLocalRepository, ReportEventSheet 3 pasos, FAB en HomePage, sync push events)

### Pendiente
| Feature | Prioridad |
|---------|-----------|
| PIN / biometría offline | Media |
| Selección de proyecto en Settings | Baja |
| Auto-sync on app start | Baja |

### Métricas
- ~18,500 LOC Dart (~95 archivos)
- 12+ tablas Drift (Users, Roles, Projects, Activities, Evidences, CatalogVersions, etc.)
- 15+ Riverpod providers
- 245+ tests unitarios/widget pasando

---

## Desktop Admin Flutter (~20%)

### Completo
- Proyecto Flutter Windows configurado (`desktop_flutter/sao_desktop`)
- Panel de validación con cola de actividades
- Visor de evidencias con metadatos, GPS, pie de foto, notas internas

### Pendiente
- Login admin
- Catalog Manager (CRUD versiones)
- Form Builder visual
- Workflow Editor
- User Admin (CRUD + RBAC)
- Conexión a backend

---

## Load Testing / QA ✅ Validado

| Test | Usuarios | Requests | Fallos | Resultado |
|------|----------|----------|--------|-----------|
| Light Load | 100 | 220 | 0% | ✅ PASS |
| Heavy Upload | 500 | 9,053 | 0% | ✅ PASS |

- Capacidad objetivo: 50 usuarios concurrentes → validado con 10x margen
- SLA: error rate 0%, p95 < 2.1s, uptime 100%
- Scripts: `load_tests/` (Locust + k6)

---

## Estructura del Repositorio

```
SAO/
├── README.md                    # Descripción + quickstart
├── ARCHITECTURE.md              # Arquitectura del sistema
├── IMPLEMENTATION_PLAN.md       # Plan por fases
├── STATUS.md                    # Este archivo
│
├── backend/                     # FastAPI backend (Python)
│   ├── app/                     # Aplicación principal
│   │   ├── api/v1/              # Endpoints REST
│   │   ├── models/              # SQLAlchemy models
│   │   ├── schemas/             # Pydantic DTOs
│   │   ├── services/            # Lógica de negocio
│   │   └── core/               # Config, auth, DB
│   ├── alembic/versions/        # Migraciones
│   ├── scripts/                 # smoke_test_prod.ps1, run_migrations_and_seed.py
│   └── tests/                   # pytest (50 tests)
│
├── frontend_flutter/sao_windows/ # App Móvil Flutter
│   ├── lib/features/            # Home, Activities, Agenda, Catalog, Auth, Evidence...
│   ├── lib/core/                # DI (GetIt), routing (go_router), theme
│   ├── lib/data/                # Repositories, Drift DB
│   ├── test/                    # Tests unitarios/widget
│   ├── DYNAMIC_FORM_BUILDER.md  # Guía DynamicFormBuilder
│   ├── EVIDENCE_CAPTURE_README.md
│   ├── EVIDENCE_FIELD_RENDERER.md
│   └── EVIDENCE_TESTS_README.md
│
├── desktop_flutter/sao_desktop/ # Desktop Admin Flutter (Windows)
│   └── lib/features/            # Validation panel, evidence viewer
│
├── load_tests/                  # Scripts de carga
│   ├── locust_light_load.py
│   ├── locust_heavy_upload.py
│   ├── locust_realistic.py
│   ├── stress_test.js / spike_test.js / soak_test.js (k6)
│   ├── analyze_results.py
│   └── results/                 # CSVs con resultados ejecutados
│
└── docs/                        # Documentación técnica y operacional
    ├── ACTIVITY_MODEL_V1.md     # Especificación modelo Activity
    ├── DESIGN_SYSTEM.md         # Sistema de diseño SAO
    ├── DEPLOYMENT_QUICKSTART.md # Deploy en 2 horas (copy-paste)
    ├── DEPLOYMENT_EXECUTION_GUIDE.md # Guía completa deployment
    ├── PRODUCTION_READINESS_CHECKLIST.md
    ├── CLOUD_SQL_INTEGRATION_GUIDE.md
    ├── CLOUD_SQL_QUICK_REFERENCE.md
    ├── RUNBOOK_CLOUD_RUN.md     # Operaciones Cloud Run
    ├── GCP_INTEGRATION_SAO.md
    ├── FLUJO_APP_AS_IS.md
    ├── FLUJO_APP_TO_BE.md
    └── VISION_TUTORIAL_APP.md
```

---

## Próximos Pasos

### Corto plazo (1-2 semanas)
1. **Sync push completo** - SyncService con push logic y resolución de conflictos en UI
2. **Selección de proyecto en Settings** - UI + persistencia en Drift

### Mediano plazo (3-4 semanas)
3. **Módulo Eventos** - `/events/*` en backend + UI móvil
4. **PIN / biometría offline** - flutter_local_auth + flutter_secure_storage
5. **CI/CD pipeline** - GitHub Actions: test + build + deploy

### Largo plazo (2+ meses)
6. **Desktop Admin completo** - Login + Catalog CRUD + Form Builder + User Admin
7. **WebSockets** - Updates en tiempo real
8. **Reportes PDF** - Templates Jinja2 + generación automática
9. **Observabilidad** - Logs estructurados, alertas Cloud Monitoring, uptime checks

---

**Última actualización:** 2026-03-02
**Progreso total estimado:** ~85% (Backend 100% + Mobile 90% + Desktop 20%)
