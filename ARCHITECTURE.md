# SAO — Architecture Reference
**Sistema de Administración Operativa**
**Versión:** 1.3.0 | **Fecha:** 2026-03-05

## Actualizacion 2026-03-10

- Backend desplegado y validado en Cloud Run revision `sao-api-00053-sm5`.
- En produccion controlada se ejecuto E2E real en modo Firestore con resultado PASS.
- `review_decision` (`POST /api/v1/review/activity/{id}/decision`) ya tiene rama Firestore operativa.
- Persiste deuda de cierre: varios endpoints siguen SQL-dependientes (`activities`, `events`, partes de `catalog` y `review`).

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
│   ├── catalog/
│   │   ├── api/       # CatalogApi (getCurrentVersion, getDiff, getEffective, getBundle, getVersionsMultiProject)
│   │   ├── sync/      # CatalogSyncService (ensureCatalogUpToDate, syncAllIfNeeded)
│   │   └── state/     # catalog_providers.dart, CatalogSyncController, CatalogSyncStatus
│   ├── config/        # AppConfig: API URL, timeouts
│   ├── network/       # ApiClient (Dio, JWT auto-refresh)
│   ├── auth/          # TokenStorage (flutter_secure_storage)
│   ├── storage/       # KvStore (SharedPreferences wrapper)
│   └── routing/       # go_router + AuthRedirectResolver
├── data/
│   └── local/         # Drift SQLite schema v8: tables.dart, app_db.dart, DAOs
├── features/
│   ├── auth/          # Login, Signup, AuthProviders
│   ├── activities/    # Wizard + DynamicFormBuilder
│   ├── agenda/        # Agenda del equipo (timeline)
│   ├── catalog/
│   │   ├── catalog_repository.dart          # Bundle loading, currentVersionId
│   │   └── data/catalog_offline_repository.dart  # CatalogIndex + CatalogBundleCache + GC
│   ├── events/        # ReportEventSheet, edit/delete, sync UPDATE/DELETE
│   ├── home/          # HomePage con FABs (actividad + evento)
│   ├── settings/      # Backend URL runtime, badge catálogo por proyecto
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
│   └── auth/          # TokenStore (JSON file en Documents/sao_session.json — persiste entre reinicios; deuda: sin cifrado)
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
  "meta": {
    "project_id": "TMQ",
    "bundle_id": "TMQ@2026-03-05T18:11:00Z",
    "generated_at": "...",
    "etag": "sha256:abc12345",
    "versions": { "effective": "TMQ@2026-03-05T18:11:00Z", "status": "published" },
    "compat": { "schema_version": "1.0", "breaking": false }
  },
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
    "color_tokens": { "status.*": "...", "severity.*": "..." },
    "form_fields":  [...],
    "rules": {
      "cascades": { "subcategories_by_activity": true, "purposes_by_activity_and_subcategory": true },
      "null_semantics": {},
      "topic_policy": { "default": "any" }
    }
  },
  "editor": { "layers": {}, "validation": {} }
}
```

**Parámetros del endpoint:**
- `GET /catalog/bundle?project_id=TMQ` — versión activa
- `GET /catalog/bundle?project_id=TMQ&version_id=TMQ@2026-03-04T...` — versión histórica exacta

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
| Desktop | JSON file (Documents/sao_session.json) | Tokens JWT (persistentes; deuda: sin cifrado — sin flutter_secure_storage) |

### 5.1 Tablas Drift (Mobile)

Versión actual del schema: **8**

| Tabla | Propósito | Desde |
|-------|-----------|-------|
| `Activities` | Actividades locales (DRAFT→SYNCED); incluye `catalog_version_id` | v1/v7 |
| `ActivityFields` | Respuestas dinámicas de formulario | v1 |
| `ActivityLog` | Historial local de acciones | v1 |
| `Evidences` | Metadatos de evidencia (LOCAL_ONLY→UPLOADED) | v1 |
| `PendingUploads` | Cola de uploads con retry logic | v4 |
| `SyncQueue` / `SyncState` | Outbox para push al backend + cursor | v1 |
| `CatActivities` / `CatSubcategories` / `CatPurposes` / `CatTopics` / `CatResults` / `CatAttendees` | Catálogo efectivo local (normalizado) | v3 |
| `CatalogVersions` / `CatalogActivityTypes` / `CatalogFields` | Schema versionado de catálogo (Sistema A) | v1 |
| `CatalogIndex` | Versión activa del bundle por proyecto (`project_id → active_version_id`) | v8 |
| `CatalogBundleCache` | Bundle JSON completo por (project_id, version_id) con GC ligado a actividades | v8 |
| `LocalEvents` | Eventos reportados localmente | v5 |
| `AgendaAssignments` | Asignaciones del equipo (agenda) | v6 |
| `Projects` / `ProjectSegments` | Proyectos y segmentos del usuario | v1 |
| `Users` / `Roles` | Perfil y rol del usuario actual | v1 |

---

## 6. Sync Architecture

Ver [SYNC.md](docs/SYNC.md) para detalle completo.

**Resumen:**
- **Push (mobile → server):** Outbox `SyncQueue` con entidades ACTIVITY y EVENT. `SyncService.pushPendingChanges()` → `POST /sync/push` (batch por proyecto). Auto-sync cada 15min + trigger en reconexión. Queue coalescing: UPSERT+DELETE→DROP; UPDATE+404→CREATE fallback.
- **Pull (server → mobile):** `POST /sync/pull?since_version=N&after_uuid=X` — implementado con cursor compuesto, paginación (`has_more`), upsert local en Drift. Pull de eventos via `GET /events?project_id&since_version`.
- **Evidencias:** Presign → Upload → Confirm (3 pasos con retry en `PendingUploads`).
- **Catálogo:** Diff incremental via `GET /catalog/diff`. Check ligero multiproyecto: `CatalogApi.getVersionsMultiProject(projectIds)` → 1 request para N proyectos. Bundle completo con versión histórica: `GET /catalog/bundle?project_id=X&version_id=Y`. Persistencia offline en `CatalogIndex` + `CatalogBundleCache` (GC seguro — retiene versiones mientras haya actividades que las referencien).

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

**Deploy:** `tools/deploy/deploy_to_cloud_run.ps1` → gate de smoke test → 100% tráfico.
**Smoke test:** `backend/scripts/smoke_test_prod.ps1`.

---

## 10. Gaps Conocidos (al 2026-03-05)

Todos los gaps críticos del diagnóstico `DIAGNOSTICO_FLUJO_100_FUNCIONAL_2026-03-05.md` están cerrados. Quedan únicamente 2 items de baja prioridad:

| Gap | Estado | Nota |
|-----|--------|------|
| Pull sync mobile | ✅ Cerrado | F3.1/F3.2 — cursor compuesto + paginación |
| PIN offline | ✅ Cerrado | F5.1 — hash SHA-256 local + endpoint `/auth/me/pin` |
| Endpoints fronts/locations | ✅ Cerrado | `/fronts`, `/locations/states`, `/locations` |
| Project ID hardcoded en desktop | ✅ Cerrado | F0.2 — `activeProjectIdProvider` |
| Workflow hardcoded en status_catalog.dart | ✅ Cerrado | F1.2/F1.3 — catalog-driven desde bundle |
| Desktop sin JWT auto-refresh | ✅ Cerrado | F5.3 — interceptor Dio con refresh |
| Observations sin prefijo /api/v1 | ✅ Falsa alarma | prefijo ya correcto en `main.py` |
| Catálogo mobile sin índice/versionado histórico | ✅ Cerrado | `CatalogIndex` + `CatalogBundleCache` schema v8 |
| Actividad no congela versión de catálogo | ✅ Cerrado | `Activities.catalogVersionId` schema v7 |
| Bundle sin `version_id` como parámetro | ✅ Cerrado | `GET /catalog/bundle?version_id=...` |
| Check de versiones por proyecto individual | ✅ Cerrado | `getVersionsMultiProject()` + `syncAllIfNeeded()` |
| UX estado de catálogo | ✅ Cerrado | Badge `● vX · actualizado/pendiente` en Settings |
| Bundle sin declaración de breaking changes | ✅ Cerrado | `meta.compat.schema_version + meta.compat.breaking` |
| FCM push para invalidación de catálogo | ⚠️ Pendiente (baja) | Pull periódico ya cubre el caso |
| CI/CD automatizado activo | ⚠️ Pendiente | `GCP_WORKLOAD_IDENTITY_PROVIDER` en Actions |
