# 🏗️ SAO - Complete 3-Tier Architecture

**Sistema de Administración y Observación**  
**Phase 3 Complete: Foundation Layer (Backend + SyncService)**  
**Status**: 35% implementation (core infrastructure ready, UI in progress)

---

## 📋 Tabla de Contenidos
1. [Visión General](#visión-general)
2. [Stack Tecnológico](#stack-tecnológico)
3. [3-Tier Architecture](#3-tier-architecture)
4. [State Machine & Workflows](#state-machine--workflows)
5. [Data Architecture](#data-architecture)
6. [Implementation Status](#implementation-status)
7. [Roadmap](#roadmap)

---

## 🎯 Visión General

**SAO** es un sistema enterprise **3-tier offline-first** for field operations:

1. **Mobile** (Operativo): Captura actividades en campo sin conexión
2. **Backend** (Source of Truth): PostgreSQL + FastAPI con RBAC + auditoría
3. **Desktop** (Coordinador): Validación workflow + admin console + reporting

### Principios Fundamentales
- ✅ **Catalog-Driven**: TODO comportamiento configurable por catálogos
- ✅ **Offline-First**: Operación completa sin conectividad
- ✅ **Multi-Tenant**: Múltiples proyectos (TMQ, TAP, SNL, QIR)
- ✅ **RBAC + Scopes**: Permisos granulares por proyecto/frente/ubicación
- ✅ **Versionado Inmutable**: Draft → Publish → Deprecated
- ✅ **Auditoría Completa**: Cada acción registrada

### Componentes del Sistema
```
┌─────────────────────────────────────────────────────────────┐
│                     BACKEND (FastAPI)                        │
│  - Auth/RBAC          - Catálogos Versionados               │
│  - Sync Incremental   - Workflow Engine                     │
│  - Evidencias         - Reporting/Audit                     │
└────────────────┬────────────────────────────┬────────────────┘
                 │                            │
       ┌─────────▼──────────┐      ┌─────────▼──────────┐
       │   APP MÓVIL        │      │   ESCRITORIO       │
       │   (Flutter)        │      │   (Flutter Win)    │
       │                    │      │                    │
       │ - Drift SQLite     │      │ - Admin Catálogos  │
       │ - Offline-First    │      │ - Form Builder     │
       │ - Sync Engine      │      │ - Workflow Editor  │
       │ - Form Renderer    │      │ - Preview Móvil    │
       └────────────────────┘      └────────────────────┘
```

---

## 🛠️ Stack Tecnológico

### Backend
```yaml
Framework: FastAPI 0.115+
Database: PostgreSQL 16+
ORM: SQLAlchemy 2.0
Migrations: Alembic
Auth: JWT (access + refresh tokens)
Storage: MinIO / AWS S3 (evidencias)
Cache: Redis (opcional)
```

### App Móvil (Flutter)
```yaml
Framework: Flutter 3.24+
State: Riverpod 2.6+
Database: Drift (SQLite)
HTTP: Dio
Storage: path_provider, flutter_secure_storage
Auth: biometrics, local_auth
DI: GetIt
Router: go_router
```

### Escritorio Admin (Flutter Windows)
```yaml
Framework: Flutter Desktop
UI: fluent_ui (Windows 11 style)
State: Riverpod
Database: Drift (local catalog cache)
HTTP: Dio
```

---

## 📁 Estructura del Proyecto

```
SAO/
├── backend/
│   ├── alembic/                    # Migraciones DB
│   ├── app/
│   │   ├── api/
│   │   │   ├── auth.py
│   │   │   ├── catalog.py
│   │   │   ├── activities.py
│   │   │   ├── events.py
│   │   │   ├── evidence.py
│   │   │   └── sync.py
│   │   ├── core/
│   │   │   ├── config.py
│   │   │   ├── security.py
│   │   │   ├── dependencies.py
│   │   │   └── rbac.py           # RBAC + Scope filtering
│   │   ├── models/               # SQLAlchemy models
│   │   ├── schemas/              # Pydantic DTOs
│   │   ├── services/
│   │   │   ├── catalog_service.py
│   │   │   ├── workflow_service.py
│   │   │   ├── sync_service.py
│   │   │   └── form_validator.py
│   │   └── main.py
│   ├── tests/
│   ├── requirements.txt
│   └── README.md
│
├── mobile/                        # App Flutter móvil
│   ├── lib/
│   │   ├── core/
│   │   │   ├── di/
│   │   │   ├── theme/
│   │   │   ├── routing/
│   │   │   ├── utils/
│   │   │   └── constants/
│   │   ├── data/
│   │   │   ├── local/
│   │   │   │   ├── app_db.dart
│   │   │   │   ├── tables/        # Drift tables
│   │   │   │   └── dao/
│   │   │   ├── remote/
│   │   │   │   ├── api_client.dart
│   │   │   │   └── endpoints/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   └── use_cases/
│   │   ├── features/
│   │   │   ├── auth/              # Login, PIN, biometría
│   │   │   ├── home/              # Dashboard operativo
│   │   │   ├── activities/
│   │   │   ├── events/            # Reportar eventos
│   │   │   ├── agenda/            # Coordinador
│   │   │   ├── evidence/
│   │   │   ├── catalog/
│   │   │   ├── sync/
│   │   │   └── settings/
│   │   └── main.dart
│   ├── test/
│   └── pubspec.yaml
│
├── desktop/                       # Admin catálogos (Flutter Win)
│   ├── lib/
│   │   ├── features/
│   │   │   ├── catalog_admin/
│   │   │   │   ├── form_builder/
│   │   │   │   ├── workflow_editor/
│   │   │   │   └── version_manager/
│   │   │   ├── user_admin/
│   │   │   ├── reports/
│   │   │   └── preview/          # Preview móvil
│   │   └── main.dart
│   └── pubspec.yaml
│
├── shared/                        # DTOs compartidos
│   └── catalog_package.json      # Schema de catálogos
│
├── docs/
│   ├── API.md
│   ├── CATALOG_SPEC.md
│   ├── WORKFLOW.md
│   └── DEPLOYMENT.md
│
├── ARCHITECTURE.md               # Este archivo
├── IMPLEMENTATION_PLAN.md
└── README.md
```

---

## 🗄️ Arquitectura de Datos

### Modelo Entidad-Relación (Simplificado)

```sql
-- CORE
User ──< UserRoleScope >── Role >─< RolePermission >── Permission
User ──< Activity
User ──< Event

-- PROYECTOS
Project ──< Front
Project ──< CatalogVersion
Front   ──< Activity
Front   ──< Event

-- CATÁLOGOS (Versionados)
CatalogVersion ──< CAT_ActivityType
CatalogVersion ──< CAT_EventType
CatalogVersion ──< CAT_FormField
CatalogVersion ──< CAT_ChecklistTemplate
CatalogVersion ──< CAT_WorkflowState
CatalogVersion ──< CAT_WorkflowTransition
CatalogVersion ──< CAT_EvidenceRule

-- OPERACIÓN
Activity ──< ActivityField (key-value)
Activity ──< Evidence
Activity ──< ActivityLog
Activity ──< ChecklistInstance >─< ChecklistResult

Event ──< EventField
Event ──< Evidence
Event ──< EventLog
```

### Tablas Principales

#### 1. **Autenticación y Seguridad**
```sql
-- Usuario
users (
  id UUID PRIMARY KEY,
  email VARCHAR UNIQUE,
  password_hash VARCHAR,
  pin_hash VARCHAR NULL,
  full_name VARCHAR,
  status ENUM('active','inactive','locked'),
  last_login_at TIMESTAMP,
  created_at TIMESTAMP
)

-- Roles
roles (
  id INTEGER PRIMARY KEY,
  name VARCHAR UNIQUE,  -- ADMIN, COORD, SUPERVISOR, OPERATIVO, LECTOR
  description TEXT
)

-- Permisos
permissions (
  id INTEGER PRIMARY KEY,
  code VARCHAR UNIQUE,  -- activity.create, event.edit, catalog.publish
  resource VARCHAR,     -- activity, event, catalog
  action VARCHAR        -- create, edit, delete, view
)

-- Relación Rol-Permiso
role_permissions (
  role_id INTEGER FK,
  permission_id INTEGER FK,
  PRIMARY KEY (role_id, permission_id)
)

-- Scopes (multi-tenant + geo)
user_role_scopes (
  id UUID PRIMARY KEY,
  user_id UUID FK,
  role_id INTEGER FK,
  project_id VARCHAR NULL,     -- NULL = todos
  front_id UUID NULL,          -- NULL = todos
  location_id UUID NULL,       -- NULL = todos
  assigned_by UUID FK,
  assigned_at TIMESTAMP,
  valid_until TIMESTAMP NULL
)
```

#### 2. **Proyectos y Estructura**
```sql
projects (
  id VARCHAR PRIMARY KEY,  -- 'TMQ', 'TAP', 'SNL'
  name VARCHAR,
  status ENUM('active','archived'),
  start_date DATE,
  end_date DATE NULL
)

fronts (
  id UUID PRIMARY KEY,
  project_id VARCHAR FK,
  code VARCHAR,           -- 'F1', 'F2'
  name VARCHAR,
  pk_start INTEGER NULL,  -- Cadenamiento inicio (metros)
  pk_end INTEGER NULL,    -- Cadenamiento fin
  responsible_id UUID FK  -- User supervisor
)

locations (
  id UUID PRIMARY KEY,
  estado VARCHAR,
  municipio VARCHAR,
  UNIQUE(estado, municipio)
)
```

#### 3. **Catálogos (Versionados)**
```sql
catalog_versions (
  id UUID PRIMARY KEY,
  project_id VARCHAR FK,
  version_number VARCHAR,    -- '1.0.0', '1.1.0'
  status ENUM('draft','published','deprecated'),
  hash VARCHAR,              -- SHA256 del paquete
  notes TEXT,
  published_by UUID FK NULL,
  published_at TIMESTAMP NULL,
  created_at TIMESTAMP
)

-- Tipos de Actividad
cat_activity_types (
  id UUID PRIMARY KEY,
  version_id UUID FK,
  code VARCHAR,              -- 'INSP_CIVIL', 'ASAMBLEA'
  name VARCHAR,
  description TEXT,
  icon VARCHAR NULL,
  color VARCHAR NULL,
  sort_order INTEGER
)

-- Campos del formulario (Form Builder)
cat_form_fields (
  id UUID PRIMARY KEY,
  version_id UUID FK,
  entity_type ENUM('activity','event'),
  type_id UUID FK NULL,      -- CAT_ActivityType.id
  key VARCHAR,               -- 'num_asistentes', 'hora_inicio'
  label VARCHAR,
  widget ENUM('text','number','select','date','time','gps','photo','file','textarea','checkbox'),
  required BOOLEAN,
  validation_regex VARCHAR NULL,
  options_source VARCHAR NULL,  -- Para select: 'cat_municipios', JSON array
  visible_when JSON NULL,       -- Condiciones: {"field": "tipo", "op": "==", "value": "X"}
  group_name VARCHAR NULL,
  sort_order INTEGER
)

-- Templates de Checklist
cat_checklist_templates (
  id UUID PRIMARY KEY,
  version_id UUID FK,
  type_id UUID FK,           -- CAT_ActivityType.id
  name VARCHAR,
  items JSON                 -- Array de {label, key, required}
)

-- Reglas de Evidencia
cat_evidence_rules (
  id UUID PRIMARY KEY,
  version_id UUID FK,
  type_id UUID FK,
  photo_min INTEGER DEFAULT 0,
  photo_max INTEGER NULL,
  doc_min INTEGER DEFAULT 0,
  require_minuta BOOLEAN DEFAULT FALSE,
  require_gps BOOLEAN DEFAULT TRUE,
  require_pk BOOLEAN DEFAULT FALSE,
  allowed_file_types JSON    -- ['.pdf', '.docx', '.jpg']
)

-- Estados del Workflow
cat_workflow_states (
  id UUID PRIMARY KEY,
  version_id UUID FK,
  entity_type ENUM('activity','event'),
  code VARCHAR,              -- 'PROGRAMADA', 'EN_EJECUCION'
  label VARCHAR,
  color VARCHAR,
  icon VARCHAR NULL,
  is_initial BOOLEAN,
  is_final BOOLEAN,
  sort_order INTEGER
)

-- Transiciones del Workflow
cat_workflow_transitions (
  id UUID PRIMARY KEY,
  version_id UUID FK,
  from_state_id UUID FK,
  to_state_id UUID FK,
  label VARCHAR,             -- 'Iniciar', 'Terminar', 'Validar'
  allowed_roles JSON,         -- Array de role IDs
  required_fields JSON NULL,  -- Array de field keys
  required_evidence BOOLEAN DEFAULT FALSE,
  confirm_message TEXT NULL
)
```

#### 4. **Operación (Activities & Events)**
```sql
activities (
  id UUID PRIMARY KEY,
  project_id VARCHAR FK,
  front_id UUID FK,
  activity_type_id UUID FK,
  catalog_version_id UUID FK,
  
  assigned_to_id UUID FK,
  created_by_id UUID FK,
  
  status VARCHAR,            -- Workflow state code
  title VARCHAR,
  description TEXT NULL,
  
  scheduled_date DATE,
  scheduled_start TIME NULL,
  scheduled_end TIME NULL,
  
  actual_start TIMESTAMP NULL,
  actual_end TIMESTAMP NULL,
  
  location_id UUID FK NULL,
  pk_start INTEGER NULL,
  pk_end INTEGER NULL,
  gps_lat DECIMAL NULL,
  gps_lon DECIMAL NULL,
  
  risk_level ENUM('bajo','medio','alto','prioritario') NULL,
  
  sync_status ENUM('pending','uploading','synced','error'),
  synced_at TIMESTAMP NULL,
  
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)

-- Campos dinámicos (EAV)
activity_fields (
  activity_id UUID FK,
  field_key VARCHAR,
  field_value TEXT,
  PRIMARY KEY (activity_id, field_key)
)

events (
  id UUID PRIMARY KEY,
  project_id VARCHAR FK,
  front_id UUID FK NULL,
  event_type_id UUID FK,
  catalog_version_id UUID FK,
  
  reported_by_id UUID FK,
  assigned_to_id UUID FK NULL,
  
  status VARCHAR,
  title VARCHAR,
  description TEXT,
  
  occurred_at TIMESTAMP,
  reported_at TIMESTAMP,
  
  severity ENUM('bajo','medio','alto','critico'),
  impact VARCHAR NULL,
  
  location_id UUID FK NULL,
  pk_value INTEGER NULL,
  gps_lat DECIMAL NULL,
  gps_lon DECIMAL NULL,
  
  converted_to_activity_id UUID FK NULL,
  
  sync_status ENUM('pending','uploading','synced','error'),
  created_at TIMESTAMP
)

event_fields (
  event_id UUID FK,
  field_key VARCHAR,
  field_value TEXT,
  PRIMARY KEY (event_id, field_key)
)
```

#### 5. **Evidencias**
```sql
evidences (
  id UUID PRIMARY KEY,
  entity_type ENUM('activity','event'),
  entity_id UUID,            -- activity_id o event_id
  
  file_type ENUM('photo','document','minuta','audio'),
  file_name VARCHAR,
  file_path VARCHAR,         -- Path local o S3 key
  file_size_bytes INTEGER,
  mime_type VARCHAR,
  
  description TEXT NULL,
  
  captured_at TIMESTAMP,
  gps_lat DECIMAL NULL,
  gps_lon DECIMAL NULL,
  
  uploaded_by_id UUID FK,
  sync_status ENUM('pending','uploading','synced','error'),
  uploaded_at TIMESTAMP NULL,
  
  created_at TIMESTAMP
)
```

#### 6. **Sync y Auditoría**
```sql
sync_outbox (
  id UUID PRIMARY KEY,
  entity_type VARCHAR,       -- 'activity', 'event', 'evidence'
  entity_id UUID,
  operation ENUM('create','update','delete'),
  payload JSON,
  retry_count INTEGER DEFAULT 0,
  status ENUM('pending','processing','synced','failed'),
  error_message TEXT NULL,
  created_at TIMESTAMP,
  synced_at TIMESTAMP NULL
)

sync_state (
  id INTEGER PRIMARY KEY DEFAULT 1,
  last_sync_at TIMESTAMP NULL,
  last_pull_version VARCHAR NULL,
  CHECK (id = 1)             -- Singleton
)

activity_log (
  id UUID PRIMARY KEY,
  activity_id UUID FK,
  user_id UUID FK,
  action VARCHAR,            -- 'created', 'status_changed', 'assigned'
  from_value VARCHAR NULL,
  to_value VARCHAR NULL,
  comment TEXT NULL,
  created_at TIMESTAMP
)

audit_log (
  id UUID PRIMARY KEY,
  user_id UUID FK,
  action VARCHAR,
  resource_type VARCHAR,
  resource_id UUID NULL,
  changes JSON NULL,
  ip_address VARCHAR NULL,
  user_agent VARCHAR NULL,
  created_at TIMESTAMP
)
```

---

## 🚀 Plan de Implementación

### FASE 1: Fundamentos Backend + Auth (Semana 1-2)
**Objetivo:** Backend funcional con autenticación y catálogos base

#### Backend
- [x] ~~Setup FastAPI + SQLAlchemy + Alembic~~
- [ ] Modelos SQLAlchemy:
  - `User`, `Role`, `Permission`, `UserRoleScope`
  - `Project`, `Front`, `Location`
  - `CatalogVersion` + tablas CAT_*
- [ ] API Auth:
  - `POST /auth/login` (email/password)
  - `POST /auth/refresh`
  - `POST /auth/pin/setup`
- [ ] Middleware RBAC + Scope filtering
- [ ] Seeds iniciales (1 proyecto TMQ, 2 frentes, 5 roles)

#### Móvil
- [x] ~~Drift tables (ya existen parcialmente)~~
- [ ] Completar tablas faltantes:
  - `user_role_scopes`
  - `catalog_*` tables
- [ ] API client (Dio + interceptors)
- [ ] Auth flow:
  - Login online obligatorio
  - Refresh token
  - Offline PIN/biometría

**Entregables:**
- ✅ Backend con auth funcional
- ✅ Móvil puede login y guardar tokens
- ✅ Seeds de 1 proyecto con catálogos básicos

---

### FASE 2: Catálogos Versionados + Publicación (Semana 3-4)
**Objetivo:** Sistema de versionado Draft→Publish funcionando

#### Backend
- [ ] API Catálogos:
  - `GET /catalog/versions?projectId=...`
  - `GET /catalog/latest?projectId=...` (solo PUBLISHED)
  - `POST /catalog/versions` (crear DRAFT)
  - `POST /catalog/versions/{id}/publish`
- [ ] Servicio `CatalogService`:
  - Generación de hash del paquete
  - Validaciones antes de publish
  - JSON serialization del paquete
- [ ] Seed: Catálogo v1.0.0 para TMQ con:
  - 5 activity types
  - 3 event types
  - Form fields dinámicos
  - Workflow básico (PROGRAMADA→EN_EJECUCION→TERMINADA→VALIDADA)

#### Móvil
- [ ] Descarga y aplicación de catálogos:
  - `CatalogRepository.downloadLatest()`
  - `CatalogRepository.applyCatalog(package)`
- [ ] Detección de versión local vs remota

**Entregables:**
- ✅ Backend sirve catálogos versionados
- ✅ Móvil descarga y aplica catálogos
- ✅ Catálogo inicial con tipos de actividad reales

---

### FASE 3: Motor de Formularios Dinámicos (Semana 5-6)
**Objetivo:** Renderizar formularios desde catálogos

#### Móvil
- [ ] `DynamicFormBuilder` widget:
  - Lee `cat_form_fields` por `type_id`
  - Renderiza widgets según `widget` type:
    - `text` → `TextField`
    - `number` → `TextField(keyboardType: number)`
    - `select` → `DropdownButton`
    - `date` → `DatePicker`
    - `time` → `TimePicker`
    - `gps` → Botón GPS con display lat/lon
    - `photo` → `ImagePicker`
    - `textarea` → `TextField(maxLines: 5)`
  - Validación según `required` y `validation_regex`
  - Visibilidad condicional (`visible_when`)
- [ ] Guardar campos en `activity_fields` (EAV)
- [ ] Integrar en Wizard actual

**Entregables:**
- ✅ Formularios completamente dinámicos
- ✅ Validaciones funcionando
- ✅ No más hardcode de campos

---

### FASE 4: Workflow Engine (Semana 7-8)
**Objetivo:** Transiciones de estado configurables

#### Backend
- [ ] `WorkflowService`:
  - `get_available_transitions(activity_id, user_id)`
    - Filtra por roles permitidos
    - Valida campos requeridos
    - Valida evidencia mínima
  - `execute_transition(activity_id, transition_id, user_id)`
- [ ] API:
  - `GET /activities/{id}/transitions`
  - `POST /activities/{id}/transition`

#### Móvil
- [ ] Widget `WorkflowActions`:
  - Botones dinámicos según transiciones disponibles
  - Confirmación si existe `confirm_message`
  - Validación antes de ejecutar
- [ ] Actualización de estado local + sync
- [ ] Logs de cambios de estado en `activity_log`

**Entregables:**
- ✅ Workflow completamente configurable
- ✅ Validaciones antes de transiciones
- ✅ Audit trail de cambios

---

### FASE 5: Sync Incremental (Semana 9-10)
**Objetivo:** Sincronización robusta offline-first

#### Backend
- [ ] API Sync:
  - `POST /sync/push` (recibe `sync_outbox` items)
  - `GET /sync/pull?since=...` (cambios incrementales)
- [ ] Resolución de conflictos:
  - Last-write-wins (por `updated_at`)
  - Notificar conflictos al móvil

#### Móvil
- [ ] `SyncEngine`:
  - `pushPendingChanges()`:
    - Lee `sync_outbox`
    - Envía en lotes
    - Marca como synced o retry
  - `pullRemoteChanges()`:
    - Descarga cambios desde `last_sync_at`
    - Aplica localmente
  - `syncAll()` (push + pull)
- [ ] UI:
  - Indicador de sync en AppBar
  - Pantalla de conflictos (si los hay)
  - Retry manual

**Entregables:**
- ✅ Sync automático en background
- ✅ Retry con backoff exponencial
- ✅ Detección de conflictos

---

### FASE 6: Eventos + Coordinador (Semana 11-12)
**Objetivo:** Reportar eventos y agenda de coordinador

#### Backend
- [ ] API Events:
  - `POST /events`
  - `GET /events?projectId=...&status=...`
  - `POST /events/{id}/convert-to-activity`

#### Móvil
- [ ] Feature `events/`:
  - FAB "Reportar Evento"
  - BottomSheet en 3 pasos:
    1. Tipo de evento + descripción
    2. Ubicación (PK/GPS)
    3. Evidencia + impacto
  - Lista de eventos reportados
- [ ] Feature `agenda/`:
  - (Ya existe parcialmente)
  - Conectar con backend
  - Asignación con detección de conflictos
  - Crear actividades desde eventos

**Entregables:**
- ✅ Reportar eventos desde móvil
- ✅ Convertir evento → actividad
- ✅ Agenda coordinador funcional

---

### FASE 7: Escritorio Admin (Semana 13-16)
**Objetivo:** App de administración de catálogos

#### Desktop (Flutter Windows)
- [ ] Setup proyecto Flutter Desktop
- [ ] UI con `fluent_ui` (Windows 11 style)
- [ ] Features:
  - Login admin
  - **Catalog Manager**:
    - Lista de versiones
    - Crear nueva versión (DRAFT)
    - Editar DRAFT
    - Publish (con confirmación)
  - **Form Builder**:
    - Drag & drop de campos
    - Configuración de validaciones
    - Preview en tiempo real
  - **Workflow Editor**:
    - Canvas visual de estados
    - Editar transiciones (roles, validaciones)
  - **User Admin**:
    - CRUD usuarios
    - Asignar roles con scopes
  - **Preview Móvil**:
    - Simula cómo se ve en móvil

**Entregables:**
- ✅ Admin desktop funcional
- ✅ Publicación de catálogos desde desktop
- ✅ Form builder visual

---

### FASE 8: Evidencias + Storage (Semana 17)
**Objetivo:** Upload y gestión de archivos

#### Backend
- [ ] Integración con MinIO/S3
- [ ] API:
  - `POST /evidence/upload` (multipart)
  - `GET /evidence/{id}/download` (pre-signed URL)
- [ ] Compresión de imágenes antes de subir

#### Móvil
- [ ] Upload en background
- [ ] Retry automático
- [ ] Visualización de evidencias

---

### FASE 9: Reportes y Auditoría (Semana 18)
**Objetivo:** Generación de reportes Word/PDF

#### Backend
- [ ] Templates con Jinja2
- [ ] Generación de PDF (reportlab)
- [ ] API:
  - `POST /reports/generate`
  - `GET /reports/{id}/download`

#### Desktop
- [ ] UI para seleccionar período y filtros
- [ ] Preview de reportes
- [ ] Download

---

## 📊 Roadmap y Prioridades

### Q1 2026 (Meses 1-3)
- ✅ Fases 1-6: Backend + Móvil core + Sync
- 🎯 **MVP listo para piloto en campo**

### Q2 2026 (Meses 4-6)
- ✅ Fases 7-9: Desktop admin + Reportes
- 🎯 **Sistema completo en producción**

### Q3 2026 (Post-MVP)
- Notificaciones push
- Dashboard analytics
- Integraciones con sistemas externos
- App iOS

---

## 📝 Convenciones y Estándares

### Git Workflow
```bash
main           # Producción
├── develop    # Integración
    ├── feature/fase1-auth
    ├── feature/fase2-catalogs
    └── feature/fase3-forms
```

### Commits
```
feat(auth): implement JWT refresh token
fix(sync): retry logic for failed uploads
docs(api): add catalog endpoints documentation
test(workflow): add transition validation tests
```

### PRs
- Revisión obligatoria antes de merge
- Tests pasando
- Coverage mínimo 70%

---

## 🧪 Testing

### Backend
```bash
pytest tests/
pytest --cov=app tests/
```

### Móvil
```bash
flutter test
flutter test --coverage
```

### Desktop
```bash
flutter test
```

---

## 🚀 Deployment

### Backend (Docker)
```yaml
# docker-compose.yml
services:
  api:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://...
      JWT_SECRET: ...
  
  db:
    image: postgres:16
    volumes:
      - pgdata:/var/lib/postgresql/data
  
  minio:
    image: minio/minio
    command: server /data
```

### Móvil
```bash
# Android
flutter build apk --release

# iOS (futuro)
flutter build ios --release
```

### Desktop
```bash
flutter build windows --release
```

---

## 📚 Referencias

- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [Drift Docs](https://drift.simonbinder.eu/docs/)
- [Riverpod Docs](https://riverpod.dev/)
- [SQLAlchemy 2.0](https://docs.sqlalchemy.org/)

---

**Última actualización:** 2026-02-17
**Versión del documento:** 1.0
