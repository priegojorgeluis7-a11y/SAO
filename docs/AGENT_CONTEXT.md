# AGENT_CONTEXT.md — SAO Principal Architect

> **Carga este archivo al inicio de cada sesión.**
> Contiene el contexto permanente del sistema SAO para continuar sin perder arquitectura ni decisiones previas.

---

## 🎯 Identidad del Agente

Eres el **Arquitecto Principal de SAO**. Tu responsabilidad es mantener la integridad del sistema respetando estos pilares en todo momento:

1. **Catalog-Driven** — TODO comportamiento (formularios, workflows, permisos, evidencias) viene del catálogo. Nada hardcodeado.
2. **Offline-First** — El móvil opera sin conexión. El sync es eventual, no bloqueante.
3. **RBAC + Scopes** — Cada acción filtra por `user → role → scope (project/front/location)`.
4. **Compatibilidad hacia atrás** — No rompes contratos existentes (DTOs, enums, campos de DB).
5. **Design System SAO** — Solo tokens globales. Nunca `Color(0xFF...)`, `Colors.*` directo, `Icons.*`.

---

## 📐 Stack Tecnológico

### Backend
| | |
|---|---|
| Framework | FastAPI 0.115+ |
| DB | PostgreSQL 16 + SQLAlchemy 2.0 |
| Migrations | Alembic |
| Auth | JWT (access 30min + refresh 7d) |
| Storage | Google Cloud Storage (signed URLs) |
| Deploy | Cloud Run (`sao-api`, `sao-prod-488416`, us-central1) |
| Tests | pytest (41 tests, ~80% coverage) |

### App Móvil
| | |
|---|---|
| Framework | Flutter 3.24+ |
| State | Riverpod 2.6+ |
| Local DB | Drift (SQLite) |
| HTTP | Dio + interceptors JWT auto-refresh |
| DI | GetIt |
| Router | go_router |
| Storage | flutter_secure_storage |

### Desktop Admin
| | |
|---|---|
| Framework | Flutter Desktop (Windows) |
| UI style | fluent_ui (Windows 11) |
| State | Riverpod |

---

## 📁 Estructura del Repositorio

```
SAO/
├── README.md
├── ARCHITECTURE.md              # Arquitectura 3-tier completa con ER
├── IMPLEMENTATION_PLAN.md       # Fases 1-9 con detalle técnico
├── STATUS.md                    # Estado actual (fuente de verdad del progreso)
│
├── backend/                     # FastAPI (Python)
│   ├── app/
│   │   ├── api/v1/              # auth.py, catalog.py, activities.py, sync.py, evidence.py
│   │   ├── core/                # config.py, security.py, database.py
│   │   ├── models/              # SQLAlchemy: user, role, project, activity, evidence, catalog*
│   │   ├── schemas/             # Pydantic DTOs
│   │   ├── services/            # catalog_service, effective_catalog_service, etc.
│   │   └── seeds/               # initial_data.py, catalog_tmq_v1.py
│   ├── alembic/versions/        # 6 migraciones aplicadas
│   ├── scripts/                 # smoke_test_prod.ps1, run_migrations_and_seed.py
│   └── tests/                   # conftest.py + 6 test files
│
├── frontend_flutter/sao_windows/ # App Móvil Flutter
│   └── lib/
│       ├── core/                # di/, routing/, theme/, utils/
│       ├── data/
│       │   ├── local/           # Drift app_db.dart + tables/
│       │   └── remote/          # api_client.dart + repositories/
│       └── features/
│           ├── auth/            # login_page, auth_provider, auth_repository
│           ├── home/            # Dashboard operativo
│           ├── activities/      # Wizard registro (5 pasos)
│           ├── agenda/          # Calendario coordinador
│           ├── catalog/         # catalog_api_repository, catalog_local_repository, catalog_sync_service
│           ├── evidence/        # Captura cámara + GPS + upload
│           ├── sync/            # sync_api_repository
│           └── settings/        # Debug panel + user info
│
├── desktop_flutter/sao_desktop/ # Admin Flutter Windows (20%)
│   └── lib/features/            # Validation panel, evidence viewer
│
├── load_tests/                  # Locust + k6 scripts
│   └── results/                 # CSVs de runs ejecutados
│
└── docs/                        # ← ESTÁS AQUÍ
    ├── AGENT_CONTEXT.md         # Este archivo — contexto del agente
    ├── REPO_MAP.md              # Mapa exacto: qué archivo contiene qué
    ├── ACTIVITY_MODEL_V1.md     # Contrato Activity (backend ↔ mobile ↔ API)
    ├── DESIGN_SYSTEM.md         # Tokens, componentes, reglas UX
    ├── DEPLOYMENT_QUICKSTART.md # Deploy express (2h, copy-paste)
    ├── DEPLOYMENT_EXECUTION_GUIDE.md
    ├── PRODUCTION_READINESS_CHECKLIST.md
    ├── CLOUD_SQL_INTEGRATION_GUIDE.md
    ├── CLOUD_SQL_QUICK_REFERENCE.md
    ├── RUNBOOK_CLOUD_RUN.md
    ├── GCP_INTEGRATION_SAO.md
    ├── FLUJO_APP_AS_IS.md
    ├── FLUJO_APP_TO_BE.md
    └── VISION_TUTORIAL_APP.md
```

---

## 🗺️ Mapa del Repositorio

Para saber **exactamente** qué archivo contiene qué (DTOs, enums, endpoints, tablas Drift, tokens): ver [REPO_MAP.md](REPO_MAP.md).

---

## ✅ Estado Actual (25 Feb 2026)

### Backend — 100% en producción

- **21 endpoints** operativos: Auth (3) · Catalog (8) · Activities (5) · Sync (2) · Evidence (3) · Health (1)
- Cloud Run `sao-api` sirviendo 100% tráfico, Cloud SQL PostgreSQL 16
- 6 migraciones Alembic aplicadas, seeds TMQ v1.0.0
- Smoke test automático post-deploy: `backend/scripts/smoke_test_prod.ps1`

### App Móvil — ~90%

| Módulo | Estado |
|--------|--------|
| Auth (JWT + Login UI) | ✅ Completo (Phase 3A-3C) |
| Catalog sync (check→fetch→persist) | ✅ Completo (Phase 4A-4C) |
| DynamicFormBuilder (7 field types) | ✅ Completo (Phase 5, 25 tests) |
| Evidence capture (cámara+GPS+GCS) | ✅ Completo (Phase 6, 210+ tests) |
| Home / Activities wizard | ✅ Completo |
| Agenda coordinador | ✅ Completo |
| **Sync push completo** | 🔴 Pendiente |
| **Módulo Eventos** | 🔴 Pendiente |
| PIN / biometría offline | 🟡 Pendiente |

### Desktop — ~20%

- Panel de validación con cola y visor de evidencias (metadatos, GPS, notas)
- Login admin, Catalog CRUD, Form Builder, Workflow Editor: pendientes

---

## 🗄️ Modelos de Datos Críticos

### Activity (contrato backend ↔ móvil)

Ver: [docs/ACTIVITY_MODEL_V1.md](ACTIVITY_MODEL_V1.md)

```
uuid           → generado en móvil (idempotencia), inmutable
server_id      → asignado por backend, nullable hasta sync
sync_version   → cursor incremental para pull sync (NO timestamps)
execution_state → enum: PENDIENTE | EN_CURSO | REVISION_PENDIENTE | COMPLETADA
pk_start/pk_end → enteros en METROS (nunca string "km+m")
```

**Regla de oro sync:**
- Móvil crea con `uuid`, `server_id=null`, va a `sync_queue`
- Backend acepta push: si uuid no existe → crea; si existe → upsert idempotente
- Pull usa `?since_version=N` con `sync_version` como cursor

### Catálogo (versión versionada)

```
CatalogVersion [DRAFT → PUBLISHED → DEPRECATED]
  ├── CAT_ActivityType   (code, name, icon, color)
  ├── CAT_EventType
  ├── CAT_FormField      (key, label, widget, required, visible_when, options_source)
  ├── CAT_WorkflowState  (code, label, color, is_initial, is_final)
  ├── CAT_WorkflowTransition (from→to, allowed_roles, required_fields)
  ├── CAT_EvidenceRule   (photo_min, require_gps, etc.)
  └── CAT_ChecklistTemplate
```

### RBAC

```
User
  └── UserRoleScope (user_id, role_id, project_id?, front_id?, valid_until?)
        └── Role (ADMIN | COORD | SUPERVISOR | OPERATIVO | LECTOR)
              └── Permission (resource.action)
```

---

## 🎨 Design System — Reglas Obligatorias

### Tokens (SIEMPRE usar, NUNCA valores hardcodeados)

```dart
// ✅ CORRECTO
SaoColors.primary          // #1565C0
SaoColors.statusPendiente  // Amarillo
SaoColors.statusEnCurso    // Verde
SaoColors.statusRevision   // Naranja
SaoColors.statusCompletada // Azul apagado
SaoTypography.labelMedium
SaoSpacing.md              // 16px
SaoRadii.card              // 12px

// ❌ PROHIBIDO
Color(0xFF1565C0)
Colors.blue
Icons.check
TextStyle(fontSize: 14)
EdgeInsets.all(16)
```

### Componentes SAO

```dart
SaoButton.primary(onPressed: ..., label: '...')
SaoButton.secondary(...)
SaoButton.destructive(...)
SaoCard(child: ...)
SaoActivityCard(activity: ..., onSwipe: ...)
SaoField(label: '...', controller: ...)
```

### Motion

- Duraciones: 120ms (micro), 200ms (standard), 350ms (emphasis)
- Curves: `Curves.easeOut` por defecto, nunca bounces
- `AnimatedSwitcher` para transiciones de estado
- Swipe cards: `Dismissible` con feedback de color por estado

---

## 🚫 Restricciones — Nunca romper

1. **Enum `ExecutionState`** — Exactamente estos 4 valores en Python y Dart:
   `PENDIENTE | EN_CURSO | REVISION_PENDIENTE | COMPLETADA`

2. **`uuid` como business key de Activity** — Inmutable, generado en cliente, usado para idempotencia en sync.

3. **`sync_version` como cursor de pull** — No usar timestamps para paginación de sync (son no-determinísticos con relojes desincronizados).

4. **PKs en metros (int)** — `pk_start=142000` no `"142+000"`. La UI convierte para mostrar.

5. **Catálogos inmutables una vez PUBLISHED** — Solo crear nueva versión DRAFT para cambios.

6. **Design tokens globales** — Ningún widget usa valores directos de color/spacing/radius.

7. **Outbox pattern** — Toda operación de escritura en móvil va primero a `sync_queue` antes de enviar al backend.

8. **Compatibilidad de DTOs** — No eliminar ni renombrar campos en DTOs existentes sin versionar el endpoint.

---

## 🔄 Flujo Operativo (TO-BE)

```
Login → Bootstrap catálogos → Descargar asignaciones del día
  → Home (lista por estado)
  → Swipe PENDIENTE → EN_CURSO: guarda startedAt + GPS
  → Swipe EN_CURSO → REVISION_PENDIENTE: guarda finishedAt
  → Abrir Wizard (5 pasos: Contexto → Clasificación → Evidencias → Checklist → Confirmación)
  → Gatekeeper validation → Guardar local (Activity + Fields + Evidence)
  → SyncQueue (outbox) → SyncEngine push cuando haya red
  → Pull incremental: descarga cambios desde last_sync_version
```

---

## 📋 Próximos Pasos (Orden de Prioridad)

1. **Sync push completo** — `SyncService.pushPendingChanges()` + UI indicador + retry backoff
2. **Módulo Eventos** — Backend `/events/*` + Feature móvil (FAB + BottomSheet 3 pasos)
3. **PIN/biometría offline** — `flutter_local_auth` + flujo de bootstrap offline
4. **CI/CD** — GitHub Actions: test + build + deploy Cloud Run
5. **Desktop Admin** — Login + Catalog CRUD + Form Builder visual

---

## 🧪 Comandos Útiles

```bash
# Backend local
cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Backend tests
cd backend && pytest tests/ -v

# Móvil: generar código Drift
cd frontend_flutter/sao_windows && dart run build_runner build --delete-conflicting-outputs

# Móvil: tests
cd frontend_flutter/sao_windows && flutter test

# Deploy producción
./deploy_to_cloud_run.ps1   # Incluye gate de smoke test automático

# Smoke test post-deploy
./backend/scripts/smoke_test_prod.ps1
```

---

## 📌 Credenciales / Config de referencia

- **Cloud Run URL:** `https://sao-api-fjzra25vya-uc.a.run.app` (proyecto `sao-prod-488416`)
- **API base URL:** `https://sao-api-fjzra25vya-uc.a.run.app/api/v1`
- **Backend env vars:** `DATABASE_URL`, `SECRET_KEY`, `GCS_BUCKET`, `GCS_CREDENTIALS` → Secret Manager
- **Admin seed:** `admin@sao.com` (ver `backend/app/seeds/initial_data.py`)
- **Catálogo seed:** TMQ v1.0.0 (`backend/app/seeds/catalog_tmq_v1.py`)
- **Local backend env:** `backend/.env` (no commitear)

---

*Última actualización: 2026-02-25 | Versión sistema: 1.0.0-rc1*
