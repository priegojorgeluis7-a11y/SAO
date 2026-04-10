# Mobile Flutter App - Home Page Implementation Summary

## File Location
- **Primary Location**: `frontend_flutter/sao_windows/lib/features/home/`
- **Main Files**:
  - `home_page.dart` - Main HomePage widget and state management
  - `home_task_sections.dart` - Task grouping/sectioning logic
  - `widgets/home_task_inbox.dart` - Task section rendering components
  - `models/today_activity.dart` - Activity data model
  - `completed_synced_activities_page.dart` - Secondary page for completed activities

---

## Home Widget Structure

### Widget Type
- **Class**: `HomePage extends ConsumerStatefulWidget`
- **State**: `_HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver`
- **Architecture**: Riverpod-based state management with local Dart state

### Constructor Parameters
```dart
HomePage({
  required String selectedProject,
  required VoidCallback onTapProject,
})
```

---

## State Management & Providers Used

### Providers (Riverpod)
1. **`kvStoreProvider`** - Key-value store for persisting preferences
2. **`offlineModeProvider`** - Offline/online status tracking
3. **`currentUserProvider`** - Current authenticated user information
4. **`syncOrchestratorProvider`** - Global sync orchestration state
5. **`catalogSyncServiceProvider`** - Catalog version sync service
6. **`catalogProviders`** (from core) - Catalog-related read operations

### Local State Variables (Mutable)
```dart
List<TodayActivity> _items = []              // Current activity list
bool _loadingActivities = true               // Loading flag
String _query = ''                           // Search query
FilterMode _filterMode = FilterMode.totales  // Activity filter mode
DateRangeFilter _dateRangeFilter = DateRangeFilter.hoy
Map<String, bool> _expandedByFrente = {}     // Expansion state per frente
bool _isAdminViewer = false                  // Role-based filtering
bool _isOperativeViewer = true               // Operative role flag
```

### Data Access Objects (DAOs)
- **`ActivityDao`** - Queries activities from local SQLite database
- **`AgendaUsersRepository`** - User/resource data
- **`AssignmentsRepository`** - Activity assignments

---

## Activity Data Model

### TodayActivity Class
```dart
class TodayActivity {
  final String id;
  final String title;
  final String frente;                      // Front/segment name
  final String municipio;
  final String estado;
  final int? pk;
  final ActivityStatus status;              // {vencida, hoy, programada}
  final DateTime createdAt;
  final ExecutionState executionState;      // {pendiente, enCurso, revisionPendiente, terminada}
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final String? gpsLocation;
  final bool isUnplanned;                   // Marked as unplanned activity
  final bool isRejected;
  final ActivitySyncState syncState;        // {pending, synced, error, unknown}
  final String operationalState;            // Derived from flow
  final String reviewState;                 // Derived from flow
  final String nextAction;                  // Primary action indicator
  final String? assignedToUserId;
  final String? assignedToName;
}
```

### Enum Types
```dart
enum ActivityStatus { vencida, hoy, programada }
enum ExecutionState { pendiente, enCurso, revisionPendiente, terminada }
enum ActivitySyncState { pending, synced, error, unknown }
enum FilterMode { totales, vencidas, completadas, pendienteSync }
enum DateRangeFilter { hoy, semana, mes }
```

---

## Activity Action Types & Flow Projection

### Next Action Types (Primary Actions)
All activities have a `nextAction` field derived from operational and review states:

| Action | Display Label | Triggered By |
|--------|--------------|--------------|
| `INICIAR_ACTIVIDAD` | "Iniciar actividad" | No start time + not rejected + synced |
| `TERMINAR_ACTIVIDAD` | "Terminar actividad" | Started but not finished |
| `COMPLETAR_WIZARD` | "Completar captura" | Status = REVISION_PENDIENTE |
| `CORREGIR_Y_REENVIAR` | "Corregir y reenviar" | Status = RECHAZADA (rejected review) |
| `REVISAR_ERROR_SYNC` | "Revisar error de sync" | Sync lifecycle = SYNC_ERROR |
| `SINCRONIZAR_PENDIENTE` | "Sincronizar pendiente" | Sync = READY_TO_SYNC or LOCAL_ONLY |
| `ESPERAR_DECISION_COORDINACION` | "Esperando revision" | Finished + review pending (PENDING_REVIEW) |
| `CERRADA_CANCELADA` | "Cancelada" | Status = CANCELED |
| `SIN_ACCION` | "Sin accion" | Completed + synced + not in review |

### Operational & Review States (Derived)
```dart
// operationalState:
'PENDIENTE'       // Not started
'EN_CURSO'        // Started  
'POR_COMPLETAR'   // Started and/or finished but needs work
'CANCELADA'       // Canceled

// reviewState:
'NOT_APPLICABLE'  // No review applicable
'REJECTED'        // Explicitly rejected for corrections
'PENDING_REVIEW'  // Submitted and awaiting review decision
```

### Flow Projection Logic
Located in: `lib/core/flow/activity_flow_projection.dart`

Flow is derived from:
- Local status field (CANCELED, RECHAZADA, REVISION_PENDIENTE, etc.)
- Timestamps (startedAt, finishedAt)
- Sync lifecycle (SYNCED, SYNC_ERROR, READY_TO_SYNC, LOCAL_ONLY)

---

## Activity Display & Grouping

### Task Sections (Home Task Sections)
Activities are grouped into collapsible sections by `nextAction`:

```
Ordered Sections:
1. por_iniciar (INICIAR_ACTIVIDAD)
   └─ "Por iniciar" - Listas para arrancar
2. en_curso (TERMINAR_ACTIVIDAD)
   └─ "En curso" - Trabajo en progreso
3. por_completar (COMPLETAR_WIZARD)
   └─ "Por completar" - Capturas pendientes de cerrar
4. por_corregir (CORREGIR_Y_REENVIAR)
   └─ "Por corregir" - Items devueltos
5. error_sync (REVISAR_ERROR_SYNC)
   └─ "Error de envio" - Requieren intervención
6. pendiente_sync (SINCRONIZAR_PENDIENTE)
   └─ "Lista para sincronizar" - Listas localmente
7. en_revision (ESPERAR_DECISION_COORDINACION)
   └─ "En revision" - Esperando decision
8. otras (Other/SIN_ACCION)
   └─ "Otras" - Items fuera de bandejas principales
```

### Sub-grouping within Sections
Each task section is further grouped by **frente** (front/segment name):
```
por_iniciar/
  ├─ Frente A
  │  └─ Activities...
  ├─ Frente B
  │  └─ Activities...
  └─ Frente C
     └─ Activities...
```

### HomeActivityRecord (Database Query Result)
```dart
class HomeActivityRecord {
  final Activity activity;           // Base activity from DB
  final String? activityTypeName;    // From catalog
  final String? segmentName;         // From segment catalog
  final String? frontName;           // From activity fields or assignment
  final String? municipio;           // Geographic location
  final String? estado;              // Geographic state
  final String? assignedToUserId;    // Primary assignee
  final String? assignedToName;      // Assignee name from users table
  final bool isUnplanned;            // Marked as unplanned
}
```

---

## Activity Loading & Filtering Logic

### Data Loading Process (`_loadHomeActivities()`)
1. **Sync Assignments** - Pulls latest assignment data from backend
2. **Query by Project** - Retrieves activities for selected project via `ActivityDao.listHomeActivitiesByProject()`
3. **Assignee Filtering** - For operatives, filters to activities assigned to current user
4. **Operative Rules** - Applies `_matchesOperativeHomeRules()` filter:
   - Must be within operative window (within ±1 day of today)
   - NextAction must be one of: INICIAR_ACTIVIDAD, TERMINAR_ACTIVIDAD, COMPLETAR_WIZARD, CORREGIR_Y_REENVIAR, REVISAR_ERROR_SYNC, SINCRONIZAR_PENDIENTE
5. **Flow Projection** - Derives operational/review state and nextAction from local data
6. **Display Mapping** - Transforms to `TodayActivity` model for rendering

### Filtering Modes (UI-Level)
```dart
switch (_filterMode) {
  case FilterMode.totales:
    // Show all (base items with date range + search)
  case FilterMode.vencidas:
    // status == ActivityStatus.vencida
  case FilterMode.completadas:
    // executionState == ExecutionState.terminada
  case FilterMode.pendienteSync:
    // executionState.terminada && syncState.pending
}
```

### Date Range Filtering
```dart
DateRangeFilter.hoy    // Today only (unless activity is active/non-terminated)
DateRangeFilter.semana // Last 7 days
DateRangeFilter.mes    // Last 30 days
```
**Note**: Active (non-terminated) activities always shown regardless of date range.

### Role-Based Filtering
```dart
_isAdminViewer = true
  └─ Can see all activities across projects/users
  └─ Can filter by assigned status

_isOperativeViewer = true (default)
  └─ Sees only activities assigned to them
  └─ Limited to operative window (today ± 1 day)
  └─ Only specific nextAction types shown
```

---

## Activity Queries & Assignment Fallback

### Primary Query - Direct Activity Assignment
```
SELECT activities WHERE 
  (projectId = ? OR projectId = kAllProjects) 
  AND status != 'CANCELED'
ORDER BY createdAt DESC
```

### Assignment Resolution (3-Level Fallback)
Assignments matched by:
1. **Direct Match** - `activity.id` in `agenda_assignments`
2. **Fingerprint Match** - Project + title + pk + startAt timestamp
3. **PK+Title Match** - Project + pk + activity type name

### Assignee Resolution (Override Priority)
1. Direct `agenda_assignments.resourceId` (if matched)
2. Activity field `assignee_user_id` (custom field override)
3. Inferred from assignment fallback match

---

## UI Components

### Search & Filters
- **Search Bar**: Matches against activity title, frente, municipio, estado
- **Filter Buttons**: Totales / Vencidas / Completadas / Pendiente Sync
- **Date Range Filter**: Hoy / Semana / Mes
- **Sort**: By nextAction section, then by frente group

### Action Notifications
Home page shows notification badge for:
- Activities with `nextAction == 'CORRECCION_Y_REENVIAR'` (rejected)
- Activities with `status == ActivityStatus.vencida` (overdue)
- Activities with `nextAction == 'COMPLETAR_WIZARD'` (incomplete capture)
- Activities with `nextAction == 'REVISAR_ERROR_SYNC'` (sync errors)

### FAB (Floating Action Buttons)
- **Primary FAB** (red warning icon) - Create unplanned activity (`/wizard/register?mode=unplanned`)

### Cloud Status Indicator
- **Online/Synced** (green cloud) - Connected, no sync errors
- **Syncing** (blue cloud uploading) - Active sync in progress
- **Sync Error** (gray cloud off) - Sync encountered error
- **Offline** (gray cloud) - No network connection

---

## Key Methods & Utilities

### Activity Flow Derivation
```dart
ActivityFlowProjection deriveLocalActivityFlowProjection({
  required String localStatus,
  DateTime? startedAt,
  DateTime? finishedAt,
  required String syncLifecycle,
})
```
Returns: `{operationalState, reviewState, nextAction}`

### Operative Home Rules
```dart
bool _matchesOperativeHomeRules(TodayActivity activity)
```
- Must be within ±1 day window
- NextAction must be in allowed set

### Next Action Display Label
```dart
String nextActionLabel(String nextAction)
```
Maps action codes to user-friendly Spanish labels

### Assignment Matching
```dart
String _assignmentFingerprint({
  required String projectId,
  required String title,
  required String pk,
  required DateTime at,
})
```
Creates unique fingerprint for assignment matching

---

## Data Persistence

### Local Preferences Stored
- `home_filter_mode` - Current filter tab (FilterMode enum value)
- `home_date_range_filter` - Current date range (DateRangeFilter enum value)
- `selected_project` - Last selected project
- `catalog_version:${projectId}` - Downloaded catalog version

---

## Integration Points

### Sync Orchestrator
Listens for sync status changes to:
- Show/hide loading indicators
- Display sync completion/error messages
- Auto-refresh activity list on successful sync

### Offline Mode
When offline:
- Cloud icon shows gray "offline" state
- Catalog sync disabled
- Uses local database only

### Push Notifications
- Watches for `catalog_update` push messages
- Triggers catalog re-sync on message receipt
- Registers device for push per project

### Assignments Sync (Before Loading Activities)
Calls `_syncAssignmentsForHome()` to ensure latest agenda assignments are present before filtering

---

## Activity Display Examples

### Example 1: Recently Created, Unstarted
```
Activity: "Encuesta Cliente A"
ID: uuid-12345
Status: hoy
ExecutionState: pendiente
SyncState: synced
StartedAt: null
FinishedAt: null

Derived Flow:
  operationalState: PENDIENTE
  reviewState: NOT_APPLICABLE
  nextAction: INICIAR_ACTIVIDAD

Display Section: "por_iniciar" → "En curso" group
Label: "Iniciar actividad"
```

### Example 2: Started, Not Completed
```
Activity: "Diagnosis Visit"
ExecutionState: enCurso
StartedAt: 2026-03-24 14:00
FinishedAt: null
SyncState: synced

Derived Flow:
  operationalState: EN_CURSO
  reviewState: NOT_APPLICABLE
  nextAction: TERMINAR_ACTIVIDAD

Display Section: "en_curso" → "Por iniciar"
```

### Example 3: Submitted for Review
```
Activity: "Report"
ExecutionState: terminada
FinishedAt: 2026-03-24 16:30
SyncState: synced
Status: (normal)

Derived Flow:
  operationalState: POR_COMPLETAR
  reviewState: PENDING_REVIEW
  nextAction: ESPERAR_DECISION_COORDINACION

Display Section: "en_revision"
Label: "Esperando revision"
```

### Example 4: Review Rejected
```
Activity: "Report"
Status: RECHAZADA
ExecutionState: revisionPendiente

Derived Flow:
  operationalState: POR_COMPLETAR
  reviewState: REJECTED
  nextAction: CORREGIR_Y_REENVIAR

Display Section: "por_corregir"
Notification Badge: "Rechazada • Corregir y reenviar"
```

### Example 5: Sync Error
```
Activity: "Survey"
SyncState: error
Status: ERROR

Derived Flow:
  operationalState: (derived from timestamps)
  reviewState: NOT_APPLICABLE
  nextAction: REVISAR_ERROR_SYNC

Display Section: "error_sync"
Label: "Error de envio"
```

---

## Architecture Notes

### Design Pattern
- **UI Pattern**: ConsumerStatefulWidget with local mutable state (not fully reactive)
- **Database**: Drift ORM with SQLite backend
- **State Provider**: Riverpod for global state (providers)
- **Local State**: Dart setState() for ephemeral UI state (filters, expansions, search)

### Data Flow
```
Backend/Sync ↓
    ↓
Drift Database (local cache)
    ↓
ActivityDao.listHomeActivitiesByProject()
    ↓
_toTodayActivity() mapping
    ↓
Flow Projection (nextAction derivation)
    ↓
Filter/Search/Group logic
    ↓
UI Rendering (buildHomeTaskSections)
```

### Performance Considerations
- Activities lazy-loaded on demand (not streaming)
- Filtering done in-memory after query
- Assignments pre-loaded and keyed for O(1) lookup
- Expansion state persisted locally by frente identifier
- Search done with simple substring matching

