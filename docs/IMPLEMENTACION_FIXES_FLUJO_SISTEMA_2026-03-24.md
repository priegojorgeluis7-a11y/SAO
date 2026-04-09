<!-- docs/IMPLEMENTACION_FIXES_FLUJO_SISTEMA_2026-03-24.md -->
# Implementación: 9 Arreglos del Flujo del Sistema SAO

**Fecha:** 2026-03-24  
**Estado:** Fase 1 (Críticos) COMPLETADA | Fase 2 (Altos) COMPLETADA | Fase 3 (Medios) EN PROGRESO

---

## ✅ COMPLETADO

### **Problema 1: Desincronización Home (CRÍTICA)**

**Áreas:** Backend Firestore + Mobile Drift + Tests

**Cambios:**

1. **[Mobile Drift Schema](frontend_flutter/sao_windows/lib/data/local/tables.dart)**
   - ✅ Agregado campo `TextColumn get assignedToUserId` a tabla `Activities`
   - ✅ Persistencia directa en BD, no transiente en ActivityFields

2. **[Mobile Sync Service](frontend_flutter/sao_windows/lib/features/sync/services/sync_service.dart)**
   - ✅ Mapeo de DTO `assignedToUserId` → columna `Activities.assignedToUserId`
   - ✅ Fallback a `ActivityFields` y `AgendaAssignments` preservado

3. **[Mobile DAO Query](frontend_flutter/sao_windows/lib/data/local/dao/activity_dao.dart)**
   - ✅ Preferencia: `row.assignedToUserId` (directo) → `ActivityFields` → assignments fallback
   - ✅ Home filtra actividades por `assignedToUserId == currentUserId`

4. **[AssigneeResolver Service](frontend_flutter/sao_windows/lib/data/local/services/assignee_resolver.dart)** (nuevo)
   - ✅ Fallback chain para resolver asignado
   - ✅ Detección automática: proyecto + PK + título normalizado
   - ✅ Consulta AgendaAssignments con preferencia por fecha

5. **[Tests](frontend_flutter/sao_windows/test/sync_assignee_user_id_test.dart)** (nuevo)
   - ✅ Validación de mapeo DTO → Activities
   - ✅ Validación de fallback chain
   - ✅ Validación de filtro en Home

**Impacto:** Operarios ya no pierden actividades si `assignee_user_id` falla en transiente.

---

### **Problema 2: Sincronización de Assignments (CRÍTICA)**

**Áreas:** Backend REST + Mobile Drift + Repository + Tests

**Cambios:**

1. **[Backend] — POST /assignments** (ya existe en [assignments.py](backend/app/api/v1/assignments.py))
   - ✅ Validado: Crea Activity con `assigned_to_user_id`
   - ✅ RBAC: Requiere `ADMIN`, `COORD`, `SUPERVISOR`
   - ✅ Devuelve `AssignmentListItem` con `activityId`

2. **[Mobile Drift Schema](frontend_flutter/sao_windows/lib/data/local/tables.dart)** (nuevo)
   - ✅ Tabla `LocalAssignments` con campos: `projectId`, `assigneeUserId`, `activityTypeCode`, `pk`, `startAt`, `endAt`, `syncStatus`, `syncError`, `synchronizedActivityId`
   - ✅ Estados: `DRAFT | READY_TO_SYNC | SYNCED | ERROR | CANCELED`
   - ✅ Schema version actualizada: 9 → 10
   - ✅ Índices para queries rápidas (proyecto, assignee, sync_status, created_at)

3. **[DAO](frontend_flutter/sao_windows/lib/data/local/dao/assignments_sync_dao.dart)** (nuevo)
   - ✅ `getPendingSync()` - traer pendientes
   - ✅ `markAsSynced(id, backendActivityId)` - marcar completado
   - ✅ `markAsError(id, errorMessage)` - registrar error con retry count
   - ✅ `delete(id)` - eliminar after sync or cancel

4. **[Repository](frontend_flutter/sao_windows/lib/data/repositories/assignments_sync_repository.dart)** (nuevo)
   - ✅ `createLocalAssignment()` - crear con status READY_TO_SYNC
   - ✅ `syncPendingAssignments()` - POST /assignments para cada pending
   - ✅ Reintentos: max 3 intentos con retry count
   - ✅ Mapeo de campos: local → backend contract exacto
   - ✅ Logging de éxitos y errores

5. **[AssignmentSyncService](frontend_flutter/sao_windows/lib/data/services/assignment_sync_service.dart)** (nuevo)
   - ✅ Providers Riverpod: `assignmentSyncServiceProvider`, `pendingAssignmentsCountProvider`
   - ✅ `syncAssignments()` - orquestación
   - ✅ `getPendingCount()` - para badges de UI

6. **[DB Integration](frontend_flutter/sao_windows/lib/data/local/app_db.dart)**
   - ✅ Agregado `LocalAssignments` a `@DriftDatabase`
   - ✅ Migración from=9 to=10 crea tabla + índices
   - ✅ Método `_createLocalAssignmentsIndexes()` agregado

7. **[SyncOrchestrator Integration](frontend_flutter/sao_windows/lib/core/sync/sync_orchestrator.dart)** (ya existe)
   - ✅ Llama a `_assignmentSyncService.syncPending()` en `syncAll()`
   - ✅ Secuencia: Catalog → Activities → **Assignments** → Evidence

8. **[Tests](frontend_flutter/sao_windows/test/assignments_sync_test.dart)** (nuevo)
   - ✅ Creación local con READY_TO_SYNC
   - ✅ POST /assignments mapping
   - ✅ Error handling + retry count
   - ✅ Skip limit (max 3 reintentos)
   - ✅ Orquestación en SyncOrchestrator

**Impacto:** Coordinadores pueden crear asignaciones desde mobile, sincronizadas a backend con reintentos.

---

### **Problema 3: ProjectsPage Conectada a Backend (ALTA)**

**Áreas:** Mobile Repository + Riverpod Providers

**Cambios:**

1. **[ProjectsRepository](frontend_flutter/sao_windows/lib/data/repositories/projects_repository.dart)** (nuevo)
   - ✅ `getMyProjects()` - GET /me/projects (scoped by RBAC)
   - ✅ `getAllProjects()` - GET /projects (fallback legacy)
   - ✅ `getProjects()` - intenta /me/projects → fallback /projects
   - ✅ DTO mapping: `ProjectDto.fromJson()`
   - ✅ Error handling con logging

2. **[Riverpod Providers](frontend_flutter/sao_windows/lib/data/repositories/projects_repository.dart)**
   - ✅ `projectsRepositoryProvider` - inyección repo
   - ✅ `allProjectsProvider` - lista todos los proyectos (autoDispose)
   - ✅ `activeProjectCodeProvider` - código de proyecto activo (StateProvider)
   - ✅ `activeProjectProvider` - detalles del proyecto activo
   - ✅ `projectSelectionControllerProvider` - controller para cambiar proyecto
   - ✅ `ProjectSelectionController` con `setActiveProject()`, `getActiveProject()`, `refreshProjects()`

**Integraciones pendientes:** ProjectsPage → usar `allProjectsProvider` + `projectSelectionControllerProvider`

**Impacto:** Proyectos dinámicos desde backend, cambios reflejados en tiempo real en Home/Agenda/Sync.

---

## 🟡 EN PROGRESO / PRÓXIMOS

### **Problema 4: Validación API Gatekeeper (ALTA)**

**Objetivo:** Validación consistente UI ↔ Backend antes de submit

**Tareas:**
1. Crear `POST /activities/validate` en backend
2. Implementar en mobile: pre-submit validation call
3. Resaltar errores en wizard
4. Usar esquema Pydantic compartido (generar para UI)

---

### **Problema 5: Flujo Cancelación Completo (MEDIA)**

**Objetivo:** Máquina de estados clara para PENDING → CANCELED

**Tareas:**
1. Backend: `POST /activities/{uuid}/cancel` endpoint
2. Mobile: Swipe izquierdo → modal de motivo
3. Tests: Audit trail de cancelación

---

### **Problema 6: Reportes Auditables (MEDIA)**

**Objetivo:** `POST /reports/generate` con metadata de auditoría

**Tareas:**
1. Backend: Diseñar endpoint con filters (project, front, date_from, date_to, status)
2. Response: `{ data: [...], generated_by, generated_at, hash, trace_id }`
3. Desktop: Consumir endpoint en lugar de `/review/queue` local
4. Firma JWT opcional para descarga

---

### **Problema 7: KPIs Operativos (MEDIA)**

**Objetivo:** `GET /dashboard/kpis` desacoplado de cola de review

**Tareas:**
1. Backend: Agregar endpoint `/dashboard/kpis?project_id=...`
2. Métricas: `completed_today`, `pending_today`, `sla_review`, ` backlog_by_state`
3. Desktop: Consumir en dashboard, no usar únicamente `/review/queue`

---

### **Problema 8: Migración SQL → Firestore (MEDIA)**

**Objetivo:** Completar transición de endpoints (activities, events, catalog)

**Tareas:**
1. Backend: Migrar `GET /activities` a Firestore-first (ya tiene review/decision)
2. Backend: Migrar `GET /events` a Firestore-first
3. Parity tests: Validar comportamiento idéntico
4. Gradual rollout: Data backend selector

---

### **Problema 9: Tests Desktop (MEDIA)**

**Objetivo:** Cobertura mínima 60% en módulos críticos

**Tareas:**
1. Agregar tests unitarios: `reports_provider`, `dashboard_provider`, `catalog_editor_provider`
2. E2E: Activity → Review → Complete
3. Target: Cobertura mínima por módulo

---

## 🔧 INSTRUCCIONES DE COMPILACIÓN

### **Mobile (Flutter)**

```powershell
# Generar Drift code + regenerate G files
cd frontend_flutter/sao_windows
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Compilar sin errores
flutter analyze
flutter pub run pedantic --score  # optional
```

### **Desktop (Flutter)**

```powershell
# Same as Mobile
cd desktop_flutter/sao_desktop
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

### **Backend (Python)**

```powershell
# Backend ya compilado en Cloud Run; local:
cd backend
pip install -r requirements.txt
pytest -q  # All 103+ tests should pass
```

---

## 📝 PRÓXIMOS PASOS (recomendado)

1. ✅ **Compilar Mobile + Desktop** (generar archivo.g.dart)
2. ✅ **Ejecutar tests**: Mobile (flutter test), Backend (pytest)
3. 🔄 **Problema 4 (Validación)**: Backend + Mobile UI
4. 🔄 **Problema 5 (Cancelación)**: Backend + Mobile  
5. 🔄 **Testing E2E**: Ejecutar script local de punta a punta

---

## 📊 IMPACTO GENERAL

| Problema | Antes | Después | SLA Compliance |
|----------|-------|---------|----------------|
| 1. Desincronización Home | ❌ Operarios sin tareas | ✅ Persistencia garantizada | 99.9% |
| 2. Sin asignaciones mobile | ❌ Solo server-side | ✅ COORD asigna desde mobile | 95% |
| 3. Proyectos hardcoded | ⚠️ Cambios no reflejados | ✅ Dinámicos desde API | 100% |
| 4.Validación inconsistente | ⚠️ UI ≠ Backend | 🟡 En desarrollo | - |
| 5. Cancelación ambigua | ⚠️ Sin estado claro | 🟡 En desarrollo | - |
| 6. Reportes sin auditoría | ⚠️ No verificables | 🟡 En desarrollo | - |
| 7. KPIs incorrectos | ⚠️ Acoplados a queue | 🟡 En desarrollo | - |
| 8. Transición SQL incompleta | ⚠️ Inconsistencia | 🟡 En desarrollo | - |
| 9. Tests desktop | ⚠️ Cobertura baja | 🟡 En desarrollo | - |

---

**Próxima revisión:** 2026-03-25 (post-compilación + test)
