# SAO — Architecture Reference
**Sistema de Administración Operativa**
**Versión:** 1.2.0 | **Fecha:** 2026-03-04

---

## 1. Visión General

SAO es un sistema **3-tier offline-first** para gestión de operaciones de campo en infraestructura ferroviaria (TMQ y proyectos similares).

```
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND (FastAPI + Cloud Run)                  │
│  Auth/RBAC · Catálogos Versionados · Sync Incremental           │
│  Workflow Engine · Evidencias (GCS) · Auditoría                 │
│  PostgreSQL 16 (Cloud SQL) · 55+ endpoints REST                  │
└──────────────────┬──────────────────────────┬───────────────────┘
                   │                          │
        ┌──────────▼──────────┐   ┌──────────▼──────────┐
        │   APP MÓVIL         │   │  DESKTOP (Windows)  │
        │  (Flutter Windows)  │   │  (Flutter Windows)  │
        │                     │   │                     │
        │  Operativo de campo │   │  Coordinador/Admin  │
        │  Drift SQLite       │   │  Review workflow    │
        │  Outbox offline     │   │  Admin console      │
        │  Auto-sync 15min    │   │  Catalog editor     │
        └─────────────────────┘   └─────────────────────┘
```

### Principios No Negociables
1. **Catalog-Driven:** formularios, validaciones, colores, workflow derivan del bundle de catálogo.
2. **Offline-First:** operativo puede registrar actividades sin red; sync posterior.
3. **RBAC + Scope:** toda acción depende de `role` y `scope` (project/front/location).
4. **Versionado Inmutable:** catálogos siguen Draft → Published → Deprecated.
5. **Auditoría Completa:** cada acción queda registrada en `audit_logs`.
6. **Zero Hardcode:** colores, textos de negocio, estados, endpoints vienen de config/catálogo.

---

## 2. Capas y Contratos

### 2.1 Backend (FastAPI)

**URL Producción:** `https://sao-api-fjzra25vya-uc.a.run.app`
**Prefijo API:** `/api/v1`

```
backend/app/
├── api/v1/          # Routers REST
│   ├── auth.py      # POST login/signup/refresh, GET me
│   ├── catalog.py   # GET bundle/diff/versions, POST publish/rollback/validate
│   ├── activities.py# CRUD + soft delete por UUID
│   ├── sync.py      # POST push/pull (cursor-based)
│   ├── evidences.py # presign, complete, download-url (GCS)
│   ├── events.py    # CRUD idempotente por UUID
│   ├── users.py     # CRUD usuarios (ADMIN/SUPERVISOR)
│   ├── projects.py  # CRUD proyectos + bootstrap_from_tmq
│   ├── assignments.py # GET asignaciones por fecha
│   ├── review.py    # queue, decision (approve/reject), evidence patch
│   ├── audit.py     # GET audit_logs (ADMIN/SUPERVISOR)
│   └── observations.py # CRUD observaciones
├── models/          # SQLAlchemy ORM (18+ modelos)
├── schemas/         # Pydantic DTOs
├── services/        # Business logic (sin acoplamiento a HTTP)
├── core/
│   ├── config.py    # Settings desde env vars (no hardcode)
│   ├── security.py  # JWT encode/decode
│   └── database.py  # Engine + SessionLocal
└── seeds/           # initial_data.py + effective_catalog_tmq_v1.py
```

**Variables de Entorno Requeridas:**

| Variable | Propósito |
|----------|-----------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Firma tokens JWT |
| `GCS_BUCKET` | Bucket Google Cloud Storage (evidencias) |
| `CORS_ORIGINS` | Lista CSV de orígenes CORS permitidos |
| `ENV` | `development` / `staging` / `production` |
| `SIGNUP_INVITE_CODE` | Código requerido para registro de usuarios |
| `ADMIN_INVITE_CODE` | Código para crear usuarios ADMIN |

### 2.2 App Móvil (frontend_flutter/sao_windows)

```
lib/
├── core/
│   ├── config/        # AppConfig: API URL, timeouts
│   ├── network/       # ApiClient (Dio, JWT auto-refresh)
│   ├── auth/          # TokenStorage (flutter_secure_storage)
│   ├── sync/          # SyncOrchestrator, PendingSyncService
│   └── routing/       # go_router + AuthRedirectResolver
├── data/
│   └── local/         # Drift SQLite: tables.dart, app_db.dart, DAOs
├── features/
│   ├── auth/          # Login, Signup, AuthProviders
│   ├── activities/    # Wizard + DynamicFormBuilder
│   ├── agenda/        # Agenda del equipo (timeline)
│   ├── catalog/       # CatalogRepository (bundle loading)
│   ├── events/        # Report event sheet
│   ├── home/          # HomePage con FABs
│   ├── settings/      # Configuración
│   └── sync/          # SyncService, AutoSyncService, SyncCenterPage
└── ui/
    ├── theme/         # SaoColors (tokens centralizados)
    └── widgets/       # EvidenceGallery, SaoActivityCard
```

**Estado de sincronización:**

```
DRAFT → READY_TO_SYNC → [SyncQueue PENDING] → SYNCED
                                           ↘ ERROR (conflict / red)
```

### 2.3 Desktop (desktop_flutter/sao_desktop)

```
lib/
├── app/shell.dart     # NavigationRail: Dashboard, Ops, Planning, Catalogs, Users, Reports
├── core/
│   ├── config/data_mode.dart  # dart-define SAO_BACKEND_URL
│   └── auth/          # TokenStore (en memoria — deuda: no persiste)
├── data/repositories/
│   ├── backend_api_client.dart  # HttpClient nativo (deuda: sin JWT refresh)
│   ├── catalog_repository.dart  # Bundle loading + CatalogData
│   ├── activity_repository.dart # review queue, decision, evidence patch
│   └── assignments_repository.dart # GET asignaciones
├── features/
│   ├── admin/         # AdminShell: proyectos, usuarios, auditoría (5 páginas)
│   ├── auth/          # AppSessionController, LoginPage
│   ├── catalogs/      # CatalogsPage (UI sin editor conectado)
│   ├── dashboard/     # DashboardPage (review queue metrics)
│   ├── operations/    # ValidationPage (queue PENDING/CHANGED/GPS/REJECTED)
│   ├── planning/      # PlanningPage
│   ├── reports/       # ReportsPage
│   └── users/         # UsersPage
└── catalog/           # StatusCatalog, RiskCatalog, ActivityCatalog (local — deuda)
```

---

## 3. RBAC y Scopes

### 3.1 Roles

| Rol | Descripción | Alcance típico |
|-----|-------------|----------------|
| `ADMIN` | Superusuario: gestión total | Global |
| `SUPERVISOR` | Supervisión y reporting | Proyecto |
| `COORD` | Coordinación y validación | Proyecto / Frente |
| `OPERATIVO` | Registro de actividades en campo | Frente / Ubicación |
| `LECTOR` | Solo lectura | Proyecto |

### 3.2 Scopes (UserRoleScope)

```sql
user_role_scopes:
  user_id     UUID
  role_id     int → roles.name
  project_id  String|NULL   -- NULL = acceso a todos los proyectos
  front_id    UUID|NULL
  location_id UUID|NULL
  valid_until DateTime|NULL
```

- `project_id = NULL` → acceso a **todos** los proyectos.
- Las verificaciones de scope son en `deps.py:verify_project_access()`.

### 3.3 Permisos Granulares

| Permiso | Recurso | Acción |
|---------|---------|--------|
| `activity.create` | activity | create |
| `activity.edit` | activity | edit |
| `activity.delete` | activity | delete |
| `activity.view` | activity | view |
| `event.create` | event | create |
| `event.edit` | event | edit |
| `event.view` | event | view |
| `catalog.publish` | catalog | publish |
| `catalog.edit` | catalog | edit |
| `catalog.view` | catalog | view |
| `user.create` | user | create |
| `user.edit` | user | edit |
| `user.view` | user | view |

---

## 4. Catálogo — Fuente Única de Verdad

### 4.1 Lifecycle

```
DRAFT → [validate] → PUBLISHED → [deprecate] → DEPRECATED
  ↑                                     ↓
  └─── [rollback] ──────────────────────┘
```

### 4.2 Bundle Schema (`sao.catalog.bundle.v1`)

```json
{
  "schema": "sao.catalog.bundle.v1",
  "meta": { "project_id", "bundle_id", "generated_at", "versions" },
  "effective": {
    "entities": {
      "activities":    [...],   // 6 tipos: CAM/REU/ASP/CIN/SOC/AIN
      "subcategories": [...],   // 23 subcats anidadas por actividad
      "purposes":      [...],   // 13 propósitos (activity_id + subcategory_id?)
      "topics":        [...],   // 7 temas: Gálibos/Accesos/Tenencia/…
      "results":       [...],   // 12 tipos de resultado
      "assistants":    [...]    // 3 tipos institucionales
    },
    "relations": {
      "activity_to_topics_suggested": [...]
    },
    "rules": {
      "cascades": {},
      "constraints": [],
      "topicPolicy": { "defaultMode": "any", "byActivity": {} }
    }
  },
  "editor": { "layers": [], "validation": {}, "history": [] }
}
```

### 4.3 Uso del Bundle en Clientes

- **Formularios dinámicos:** `DynamicFormBuilder` lee `CatalogFields` derivadas del bundle.
- **Colores de categoría:** deben venir de tokens semánticos definidos en bundle (actualmente hardcoded — ver DESIGN_TOKENS.md).
- **Máquina de estados:** debe venir de `effective.rules.workflow` (actualmente hardcoded en `status_catalog.dart`).
- **Cascade dropdowns:** subcategorías → propósitos filtrados por actividad seleccionada.

---

## 5. Storage

| Capa | Storage | Propósito |
|------|---------|-----------|
| Backend | PostgreSQL 16 (Cloud SQL) | Source of truth |
| Backend | Google Cloud Storage | Evidencias (fotos, PDFs) |
| Mobile | Drift (SQLite) | Operación offline |
| Mobile | flutter_secure_storage | Tokens JWT |
| Desktop | HttpClient en memoria | Tokens JWT (deuda: no persiste) |

### 5.1 Tablas Drift (Mobile)

Versión actual del schema: **5**

| Tabla | Propósito |
|-------|-----------|
| `Activities` | Actividades locales (DRAFT→SYNCED) |
| `ActivityFields` | Respuestas dinámicas de formulario |
| `ActivityLog` | Historial local de acciones |
| `Evidences` | Metadatos de evidencia (LOCAL_ONLY→UPLOADED) |
| `PendingUploads` | Cola de uploads con retry logic |
| `SyncQueue` | Outbox para push al backend |
| `CatActivities` / `CatSubcategories` / `CatPurposes` / `CatTopics` / `CatResults` / `CatAttendees` | Catálogo efectivo local |
| `CatalogVersions` | Versión del catálogo descargado |
| `LocalEvents` | Eventos reportados localmente (schema v5) |
| `Projects` / `ProjectSegments` | Proyectos y segmentos del usuario |
| `Users` / `Roles` | Perfil y rol del usuario actual |

---

## 6. Sync Architecture

Ver [SYNC.md](docs/SYNC.md) para detalle completo.

**Resumen:**
- **Push (mobile → server):** Outbox `SyncQueue` con entidades ACTIVITY y EVENT. `SyncService.pushPendingChanges()` → `POST /sync/push` (batch por proyecto). Auto-sync cada 15min + trigger en reconexión.
- **Pull (server → mobile):** `POST /sync/pull?since_version=N` — **PARCIALMENTE IMPLEMENTADO** (orquestador existe sin fetch real).
- **Evidencias:** Presign → Upload → Confirm (3 pasos con retry en `PendingUploads`).
- **Catálogo:** Bundle completo descargado; diff incremental pendiente.

---

## 7. Workflow de Actividades

Ver [WORKFLOW.md](docs/WORKFLOW.md) para detalle completo.

**Estados:**

```
borrador → nuevo → en_revision ↔ requiere_cambios → aprobado → sincronizado
                ↓                ↓
             rechazado(✗)    rechazado(✗)

offline → sincronizado | conflicto → en_revision
```

**Roles por transición:**

| Transición | Rol requerido |
|------------|---------------|
| borrador → nuevo | OPERATIVO+ |
| nuevo → en_revision | COORD+ |
| en_revision → aprobado | COORD+ |
| en_revision → rechazado | COORD+ |
| en_revision → requiere_cambios | COORD+ |
| aprobado → APPROVE_EXCEPTION | ADMIN |

---

## 8. Design Tokens

Ver [DESIGN_TOKENS.md](docs/DESIGN_TOKENS.md).

**Regla:** ningún feature puede usar `Color(0xFF...)` directamente. Todos los colores van via `SaoColors.*` o token semántico del bundle.

---

## 9. Infraestructura y Deploy

| Componente | Servicio | Región |
|------------|---------|--------|
| Backend API | Cloud Run (`sao-api`) | us-central1 |
| Base de datos | Cloud SQL PostgreSQL 16 | us-central1 |
| Evidencias | GCS bucket | us-central1 |
| Secrets | Secret Manager | GCP |

**Deploy:** `deploy_to_cloud_run.ps1` → gate de smoke test → 100% tráfico.
**Smoke test:** `backend/scripts/smoke_test_prod.ps1`.

---

## 10. Gaps Conocidos (al 2026-03-04)

| Gap | Impacto | Tracker |
|-----|---------|---------|
| Pull sync mobile no implementado | Coordinador aprueba pero operativo no ve resultado | SERVICES_MATRIX.md |
| PIN offline | Operativo sin red no puede autenticarse | AUDIT_REPORT.md |
| Endpoints fronts/locations faltantes | RBAC scope parcial | AUDIT_REPORT.md |
| Project ID hardcoded en desktop (7 archivos) | Multi-proyecto roto | AUDIT_REPORT.md §1.5 |
| Workflow hardcoded en status_catalog.dart | Desconexión con backend | AUDIT_REPORT.md §1.4 |
| Desktop sin JWT auto-refresh | Sesión expira sin aviso | AUDIT_REPORT.md §4 |
| Observations sin prefijo /api/v1 | Ruta inconsistente | AUDIT_REPORT.md §4 |
