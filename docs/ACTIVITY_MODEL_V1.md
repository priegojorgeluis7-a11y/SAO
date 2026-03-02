# 📋 Modelo Oficial: Activity (v1)

**Autor:** SAO Team  
**Fecha:** 2026-02-18  
**Status:** ✅ OFICIAL - Contrato único entre Backend y Móvil

---

## 🎯 Propósito

Este documento define el **contrato oficial** del modelo `Activity` (v1) que **DEBE ser idéntico** entre:
- Backend (FastAPI + SQLAlchemy)
- Móvil (Flutter + Drift)
- API REST (DTOs JSON)

**Cualquier desviación causará bugs de sincronización.**

---

## 📊 1) Campos y Reglas (Contrato Único)

| Campo | Tipo (Contrato) | Origen | Reglas |
|-------|----------------|--------|--------|
| `uuid` | UUID string | Cliente | Generado en móvil al crear offline. **Inmutable**. Unique global. |
| `server_id` | int | Servidor | Autoincrement. Puede ser `null` en móvil hasta sincronizar. |
| `project_id` | string/uuid | Ambos | FK Project. **Obligatorio**. |
| `front_id` | string/uuid | Ambos | FK Front/Segment. **Nullable** si aplica "general". |
| `pk_start` | int | Ambos | PK en **metros** (recomendado). Ej: km 142+000 → 142000 enteros. |
| `pk_end` | int | Ambos | **Nullable** si puntual. Si tramo: `pk_end >= pk_start`. |
| `execution_state` | string enum | Ambos | `PENDIENTE` \| `EN_CURSO` \| `REVISION_PENDIENTE` \| `COMPLETADA` |
| `assigned_to_user_id` | int/uuid | Ambos | **Nullable** si no asignada. |
| `created_by_user_id` | int/uuid | Ambos | **Obligatorio**. |
| `catalog_version_id` | int | Ambos | FK CatalogVersion. **Obligatorio**. |
| `activity_type_code` | string | Ambos | Código de tipo de actividad del catálogo (ej: "INSP_CIVIL"). |
| `latitude` | string | Ambos | Coordenada GPS en grados decimales. **Nullable**. |
| `longitude` | string | Ambos | Coordenada GPS en grados decimales. **Nullable**. |
| `title` | string(200) | Ambos | Título de la actividad. **Nullable**. |
| `description` | text | Ambos | Descripción de la actividad. **Nullable**. |
| `created_at` | datetime UTC | Servidor* | Servidor manda "source of truth". Cliente puede setear provisional offline. |
| `updated_at` | datetime UTC | Servidor* | Siempre se actualiza en cambios. |
| `deleted_at` | datetime UTC | Servidor | Soft delete. Cliente lo replica. **Nullable**. |
| `sync_version` | int | Servidor | **Monótono incremental**. Clave para pull incremental. |

\* **En móvil:** guarda timestamps locales para UI, pero al sincronizar se reemplazan por los del servidor.

---

## 🔥 Decisiones Críticas (Te salvan del Sync)

### ✅ 1. pk_start/pk_end en **metros (int)**, NO "km+metros" string

**Razón:**
- UI puede mostrar `km+mmm`, pero persistencia y API usan **metros enteros**.
- Evitas errores de parseo, sorting, filtros y comparaciones.

**Ejemplo:**
```
PK 142+000 → 142000 (int)
PK 142+450 → 142450 (int)
PK 145+000 → 145000 (int)
```

### ✅ 2. Estado oficial: **enums idénticos** (backend y móvil)

**Contrato:**
- `execution_state` es **string** (no int) para compatibilidad y legibilidad.

**Valores permitidos:**
1. `PENDIENTE`
2. `EN_CURSO`
3. `REVISION_PENDIENTE`
4. `COMPLETADA`

**Implementación:**

```python
# Backend (SQLAlchemy)
class ExecutionState(str, enum.Enum):
    PENDIENTE = "PENDIENTE"
    EN_CURSO = "EN_CURSO"
    REVISION_PENDIENTE = "REVISION_PENDIENTE"
    COMPLETADA = "COMPLETADA"
```

```dart
// Móvil (Drift)
enum ExecutionState {
  PENDIENTE,
  EN_CURSO,
  REVISION_PENDIENTE,
  COMPLETADA
}
```

### ✅ 3. Sync contract mínimo (para que funcione sí o sí)

#### 📌 Reglas de oro

1. **`uuid` manda:** el móvil crea con uuid, el server lo usa como **idempotencia**.
2. **`server_id`** solo es "id interno" del server.
3. **`sync_version`** es el **cursor** para `/sync/pull`.

#### Flujo offline → online

**Cuando móvil crea offline:**
```json
{
  "uuid": "b7f0a123-4567-89ab-cdef-0123456789ab",
  "server_id": null,
  "sync_version": 0,
  "created_at": "2026-02-18T20:10:00Z",  // local provisional
  "updated_at": "2026-02-18T20:10:00Z"
}
```

**Cuando server acepta push:**
- Si `uuid` no existe → crea, asigna `server_id`, `sync_version`
- Si `uuid` existe → update **idempotente** (si trae cambios)

```json
{
  "uuid": "b7f0a123-4567-89ab-cdef-0123456789ab",
  "server_id": 12345,  // asignado por server
  "sync_version": 8821,  // incrementado por server
  "created_at": "2026-02-18T20:10:05Z",  // timestamp del server (source of truth)
  "updated_at": "2026-02-18T20:10:05Z"
}
```

---

## 🧩 Implementación en Backend (SQLAlchemy)

### Especificación clara

**Activity (DB)**
- `id` (server_id) → autoincrement PK
- `uuid` → **unique index** (obligatorio)
- `sync_version` → **indexado**
- `updated_at` → **indexado** (útil para auditoría)
- `deleted_at` → nullable

**Constraints:**
1. `CHECK (pk_end IS NULL OR pk_end >= pk_start)`
2. `CHECK (execution_state IN ('PENDIENTE', 'EN_CURSO', 'REVISION_PENDIENTE', 'COMPLETADA'))`

**Indexes:**
- `idx_activity_sync` → (sync_version, updated_at)
- `idx_activity_project_front` → (project_id, front_id)
- `idx_activity_pk_range` → (pk_start, pk_end)

### Código SQLAlchemy

Ver: `backend/app/models/activity.py`

```python
class Activity(BaseModel):
    __tablename__ = "activities"
    
    # IDENTITY
    uuid = Column(String(36), unique=True, nullable=False, index=True)
    # id from BaseModel
    
    # SYNC
    sync_version = Column(Integer, nullable=False, default=0, index=True)
    deleted_at = Column(DateTime, nullable=True, index=True)
    
    # TERRITORIAL
    project_id = Column(String(10), ForeignKey("projects.id"), nullable=False)
    front_id = Column(String(20), ForeignKey("fronts.id"), nullable=True)
    pk_start = Column(Integer, nullable=False, index=True)
    pk_end = Column(Integer, nullable=True)
    
    # WORKFLOW
    execution_state = Column(String(20), nullable=False, default="PENDIENTE")
    
    # ASSIGNMENT
    assigned_to_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # CATALOG
    catalog_version_id = Column(Integer, ForeignKey("catalog_versions.id"), nullable=False)
    activity_type_code = Column(String(20), nullable=False)
    
    # LOCATION
    latitude = Column(String(20), nullable=True)
    longitude = Column(String(20), nullable=True)
    
    # DETAILS
    title = Column(String(200), nullable=True)
    description = Column(Text, nullable=True)
```

---

## 📱 Implementación en Móvil (Drift)

### Especificación clara

**Activity (Drift)**
- `uuid` → TEXT **PRIMARY KEY** (o UNIQUE + surrogate key si ya tienes una PK)
- `server_id` → INT nullable + **UNIQUE**
- `sync_version` → INT default 0
- `deleted_at` → nullable

**Nota importante:**
Si hoy tu Drift usa `id` autoincrement como PK, mantén eso si quieres, pero agrega `uuid` unique y usa `uuid` como "business key" para sync.

### Código Drift (recomendado)

```dart
@DataClassName('Activity')
class Activities extends Table {
  // IDENTITY
  TextColumn get uuid => text().withLength(min: 36, max: 36)();
  IntColumn get serverId => integer().nullable()();
  
  // SYNC
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  
  // TERRITORIAL
  TextColumn get projectId => text().withLength(max: 10)();
  TextColumn get frontId => text().withLength(max: 20).nullable()();
  IntColumn get pkStart => integer()();
  IntColumn get pkEnd => integer().nullable()();
  
  // WORKFLOW
  TextColumn get executionState => text().withDefault(const Constant('PENDIENTE'))();
  
  // ASSIGNMENT
  IntColumn get assignedToUserId => integer().nullable()();
  IntColumn get createdByUserId => integer()();
  
  // CATALOG
  IntColumn get catalogVersionId => integer()();
  TextColumn get activityTypeCode => text().withLength(max: 20)();
  
  // LOCATION
  TextColumn get latitude => text().nullable()();
  TextColumn get longitude => text().nullable()();
  
  // DETAILS
  TextColumn get title => text().withLength(max: 200).nullable()();
  TextColumn get description => text().nullable()();
  
  // TIMESTAMPS
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {uuid};
}
```

---

## ✅ Payload API Recomendado (Para Alinear Todo)

### ActivityDTO (común)

```json
{
  "uuid": "b7f0a123-4567-89ab-cdef-0123456789ab",
  "server_id": 12345,
  "project_id": "TMQ",
  "front_id": "TMQ-FR-03",
  "pk_start": 142000,
  "pk_end": 145000,
  "execution_state": "EN_CURSO",
  "assigned_to_user_id": 9,
  "created_by_user_id": 1,
  "catalog_version_id": 1,
  "activity_type_code": "INSP_CIVIL",
  "latitude": "20.629500",
  "longitude": "-100.316100",
  "title": "Inspección civil km 142-145",
  "description": "Revisión estructural del tramo",
  "created_at": "2026-02-18T20:10:05Z",
  "updated_at": "2026-02-18T21:05:10Z",
  "deleted_at": null,
  "sync_version": 8821
}
```

### Schema Pydantic

Ver: `backend/app/schemas/activity.py`

```python
class ActivityDTO(BaseModel):
    uuid: str
    server_id: Optional[int] = None
    project_id: str
    front_id: Optional[str] = None
    pk_start: int
    pk_end: Optional[int] = None
    execution_state: str
    assigned_to_user_id: Optional[int] = None
    created_by_user_id: int
    catalog_version_id: int
    activity_type_code: str
    latitude: Optional[str] = None
    longitude: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    sync_version: int
```

---

## 🧨 Si NO Haces Esto, ¿Qué se Rompe?

### ❌ Sin `uuid` como llave de idempotencia
- **Duplicados:** mismo móvil envía 2 veces, crea 2 activities
- **Pérdida de datos:** no se puede identificar qué activity es cuál

### ❌ Sin `sync_version` incremental
- **Conflictos imposibles de resolver:** no sabes cuál cambio es más reciente
- **Pull lento:** tienes que mandar TODA la DB en cada sync

### ❌ Sin timestamps como cursor
- **Causa drift y edge cases:** relojes desincronizados, time zones
- **Bug con updates simultáneos**

### ❌ Si guardas PK como string "km+metros"
- **Bugs de sorting:** "142+900" > "143+100" alfabéticamente
- **Bugs de comparaciones:** no puedes hacer `pk_start BETWEEN 142000 AND 145000`
- **Bugs de filtros:** no puedes buscar por rango
- **Parseo inconsistente:** diferentes formatos, errores de validación

---

## 📝 Checklist de Implementación

### Backend
- [x] Modelo `Activity` en SQLAlchemy con todos los campos
- [x] Enum `ExecutionState` con 4 estados
- [x] Constraints: `pk_end >= pk_start`, `execution_state` válido
- [x] Indexes: sync, project_front, pk_range
- [x] Schema Pydantic `ActivityDTO`
- [ ] Migration Alembic para crear tabla
- [ ] Service `ActivityService` con CRUD básico
- [ ] Endpoints REST: POST/GET/PUT/DELETE `/activities`
- [ ] Endpoints Sync: `/sync/push`, `/sync/pull`

### Móvil
- [ ] Tabla Drift `Activities` con todos los campos
- [ ] Enum `ExecutionState` idéntico a backend
- [ ] Repository `ActivityRepository`
- [ ] Service local `ActivityService`
- [ ] Integración con `SyncQueue` (outbox pattern)

### Testing
- [ ] Unit tests backend (ActivityService)
- [ ] Integration tests (sync push/pull)
- [ ] E2E tests (móvil → backend → móvil)

---

**Última actualización:** 2026-02-18  
**Próxima revisión:** Antes de Fase 3 (Activities CRUD)
