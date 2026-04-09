# STATE SYSTEM SPECIFICATION - Unified Reference

## Overview
This document serves as the single source of truth for all state definitions and mappings across SAO backend and frontend.

---

## EXECUTION STATE
**Purpose:** Primary state that controls the activity lifecycle (mobile controls this)  
**Scope:** Only mobile can change this value  
**Persistence:** Firestore `activities.execution_state`

| Value | Meaning | Mobile Action | Backend Derives |
|-------|---------|---------------|-----------------|
| PENDIENTE | Not started | User hasn't started | operational_state=PENDIENTE |
| EN_CURSO | In progress | Timer running | operational_state=EN_CURSO |
| REVISION_PENDIENTE | Completed, waiting review | User stopped, form incomplete | operational_state=POR_COMPLETAR |
| COMPLETADA | Form complete | All requirements met | operational_state=POR_COMPLETAR |
| CANCELED | Canceled by user | User cancels | operational_state=CANCELADA |

**Validation:** Backend validates in `ActivityBase.execution_state` with Pydantic field_validator  
**Code Locations:**
- Backend: `backend/app/schemas/activity.py:10`
- Frontend: Used in sync, agenda workflows

---

## OPERATIONAL STATE  
**Purpose:** Normalized state for UI logic (always derived)  
**Scope:** Read-only on frontend, always recalculated on backend read  
**Derivation:** `infer_operational_state(execution_state)`

| Derived From | Value | Meaning |
|---|---|---|
| PENDIENTE | PENDIENTE | Inactive, not started |
| EN_CURSO | EN_CURSO | Active task with timer |
| REVISION_PENDIENTE \| COMPLETADA | POR_COMPLETAR | Needs form/checklist completion |
| CANCELED | CANCELADA | Closed without completion |
| (unknown) | PENDIENTE | Default fallback |

**Function:** `backend/app/schemas/activity.py:57-64`  
**Frontend:** Receives already-derived value from `/sync/pull`

---

## SYNC STATE  
**Purpose:** Track synchronization status with server  
**Scope:** frontend manages lifecycle, backend reports on read  
**Persistence:** Mobile app tracks in SQLite `timeline_sync_status`

### Backend Valid Values (VALID_SYNC_STATES)
```
"LOCAL_ONLY"        → Created locally, never sent to server
"READY_TO_SYNC"     → Has local changes, ready to upload  
"SYNC_IN_PROGRESS"  → Upload/download in progress
"SYNCED"            → Last known state synced with server
"SYNC_ERROR"        → Last sync attempt failed; retry needed
```

**Derivation:** `infer_sync_state(sync_state, has_local_changes, has_sync_error, sync_in_progress)`  
**Code Location:** `backend/app/schemas/activity.py:17-42`

### Frontend Enum (SyncStatus)
```dart
enum SyncStatus {
  pending,    // Maps: LOCAL_ONLY, READY_TO_SYNC
  uploading,  // Maps: SYNC_IN_PROGRESS
  synced,     // Maps: SYNCED
  error,      // Maps: SYNC_ERROR
}
```

**Code Location:** `frontend_flutter/sao_windows/lib/features/agenda/models/agenda_item.dart:3-7`

### Mapping Table (Backend → Frontend)
| Backend Value | Frontend SyncStatus | Meaning |
|---|---|---|
| LOCAL_ONLY | pending | Never sent |
| READY_TO_SYNC | pending | Waiting to upload |
| SYNC_IN_PROGRESS | uploading | Currently uploading |
| SYNCED | synced | Up-to-date |
| SYNC_ERROR | error | Failed, needs retry |

**Mapper:** `frontend_flutter/sao_windows/lib/features/sync/models/sync_status_mapper.dart`  
**Usage:** Use `SyncStatusMapper.fromBackend(backendValue)` to convert

---

## REVIEW STATE
**Purpose:** Decision status from coordinator/supervisor  
**Scope:** Applies only if execution_state in {REVISION_PENDIENTE, COMPLETADA}  
**Derivation:** `infer_review_state(execution_state, review_decision)`

### Valid Values (VALID_REVIEW_STATES)
```
"NOT_APPLICABLE"    → No review needed (activity not complete)
"PENDING_REVIEW"    → Waiting for decision
"CHANGES_REQUIRED"  → Coordinator said "fix it and resend"
"APPROVED"          → Coordinator approved (with or without exceptions)
"REJECTED"          → Coordinator rejected permanently
```

**Code Locations:**
- Backend derivation: `backend/app/schemas/activity.py:44-61`
- API contract: All responses use ENGLISH values (not Spanish)
- Review endpoint: `backend/app/api/v1/review.py`

**Important:** 
- ✅ Backend ALWAYS returns English status values in API
- ✅ Review decision endpoint stores as English in Firestore  
- ✅ Frontend translates to UI labels if needed

---

## NEXT ACTION
**Purpose:** Recommended action for frontend to suggest to user  
**Scope:** Purely informational, frontend drives actual flow  
**Priority:** review_state > sync_state > operational_state

| Condition | Value | UX Impact |
|---|---|---|
| review = PENDING_REVIEW | ESPERAR_DECISION_COORDINACION | Block actions, waiting |
| review = CHANGES_REQUIRED | CORREGIR_Y_REENVIAR | Show "fix and resubmit" |
| review = APPROVED | CERRADA_APROBADA | Terminal (read-only) |
| review = REJECTED | CERRADA_RECHAZADA | Terminal (read-only) |
| sync = SYNC_ERROR | REVISAR_ERROR_SYNC | Show error recovery |
| sync = READY_TO_SYNC | SINCRONIZAR_PENDIENTE | Suggest sync |
| operational = PENDIENTE | INICIAR_ACTIVIDAD | Show "start" button |
| operational = EN_CURSO | TERMINAR_ACTIVIDAD | Show "stop" button |
| operational = POR_COMPLETAR | COMPLETAR_WIZARD | Show form |
| operational = CANCELADA | CERRADA_CANCELADA | Terminal |
| (fallback) | SIN_ACCION | No action needed |

**Code:** `backend/app/schemas/activity.py:70-87`

---

## ACTIVITY STATUS (Desktop Catalog)
**Purpose:** Desktop-specific activity states  
**Scope:** Desktop only, not used by mobile  
**Values:** `pendingReview`, `approved`, `rejected`, `needsFix`, `corrected`, `conflict`

**Note:** Desktop should map these to operational_state/review_state values  
**Code:** `desktop_flutter/sao_desktop/lib/data/catalog/activity_status.dart`

**Migration Note:** This should eventually consolidate with operational_state

---

## UI STATES (STATUS CATALOG)
**Purpose:** Workflow rules and allowed transitions for UI  
**Scope:** Frontend (mobile + desktop)  
**Values:** `borrador`, `nuevo`, `enRevision`, `requiereCambios`, `aprobado`, `rechazado`, `sincronizado`, `offline`, `conflicto`

**Code:** `frontend_flutter/sao_windows/lib/catalog/status_catalog.dart`

**Relationship:** Maps from execution_state → UI presentation  
**Fallback:** If workflow not found in catalog, return empty list (ISSUE: Add default transitions)

---

## VALIDATION RULES

### Execution State Transitions (Mobile Driven)
```
PENDIENTE ──→ EN_CURSO  (user starts task)
           ║
           ↓
         EN_CURSO ──→ REVISION_PENDIENTE  (user stops, form incomplete)
                  ║
                  ↓
                EN_CURSO ──→ COMPLETADA  (user completes form)

Any state ──→ CANCELED  (user cancels anytime)
```

**Validation:** Mobile respects these via StatusCatalog.nextStatesFor()  
**Backend:** Does NOT validate transitions (mobile responsibility)

### Sync State Transitions (Backend/Mobile Implicit)
```
LOCAL_ONLY ──→ READY_TO_SYNC ──→ SYNC_IN_PROGRESS ──→ SYNCED
                                         ↓
                                   SYNC_ERROR ──→ SYNC_IN_PROGRESS (retry)
```

### Review State Transitions (Backend/Admin Control)
```
NOT_APPLICABLE ──→ (if execution_state changes to REVISION_PENDIENTE/COMPLETADA)
                       ↓
                  PENDING_REVIEW
                    ↙  ↓  ↘
              APPROVED  │  REJECTED
                        ↓
                 CHANGES_REQUIRED ──→ (back to PENDIENTE when user fixes)
                                         ↓
                                    PENDING_REVIEW (re-evaluation)
```

---

## API CONTRACTS

### /sync/pull Response
```json
{
  "activity": {
    "execution_state": "COMPLETADA",
    "operational_state": "POR_COMPLETAR",
    "sync_state": "SYNCED",
    "review_state": "PENDING_REVIEW",
    "next_action": "COMPLETAR_WIZARD",
    "review_decision": null,
    "created_at": "...",
    "updated_at": "..."
  }
}
```

### /review/decision Response
```json
{
  "ok": true,
  "status": "APPROVED",
  "activity_id": "...",
  "decision": "APPROVE"
}
```

---

## CONSTANTS (Copy-Paste Reference)

### Backend Constants
```python
VALID_EXECUTION_STATES = ["PENDIENTE", "EN_CURSO", "REVISION_PENDIENTE", "COMPLETADA", "CANCELED"]
VALID_OPERATIONAL_STATES = ["PENDIENTE", "EN_CURSO", "POR_COMPLETAR", "BLOQUEADA", "CANCELADA"]
VALID_SYNC_STATES = ["LOCAL_ONLY", "READY_TO_SYNC", "SYNC_IN_PROGRESS", "SYNCED", "SYNC_ERROR"]
VALID_REVIEW_STATES = ["NOT_APPLICABLE", "PENDING_REVIEW", "CHANGES_REQUIRED", "APPROVED", "REJECTED"]
```

### Frontend Constants  
```dart
enum SyncStatus {
  pending,    // LOCAL_ONLY, READY_TO_SYNC
  uploading,  // SYNC_IN_PROGRESS
  synced,     // SYNCED
  error,      // SYNC_ERROR
}
```

---

## TROUBLESHOOTING

### "Activity shows different status in Home vs Agenda"
- **Likely Cause:** Different data sources (sync/pull vs /assignments endpoint)
- **Home:** Uses `/sync/pull` + local SQLite filtering
- **Agenda:** Uses `/assignments` + backend filtering

### "States diverged between Backend and Frontend"
- **Cause:** Frontend recalculating instead of trusting Backend projections
- **Solution:** Use values from API response directly, don't recalculate
- **Files to Check:**
  - `frontend_flutter/sao_windows/lib/features/sync/services/sync_service.dart:816+`
  - Remove any state recalculation that duplicates Backend logic

### "Unknown sync_state value received"
- **Cause:** API returning value not in VALID_SYNC_STATES
- **Solution:** Update VALID_SYNC_STATES and SyncStatusMapper
- **Safe Default:** Treat unknown as "SYNCED" (safest assumption)

### "UI stuck, no transitions available"
- **Cause:** StatusCatalog.nextStatesFor() returned empty list
- **Solution:** Add fallback transitions or ensure catalog updated
- **Safe Defaults:** Allow CANCELED transition from any state

---

## IMPLEMENTATION TODOS

- [ ] Ensure all API responses use consistent English values
- [ ] Add explicit SyncStatusMapper for all Backend→Frontend conversions
- [ ] Remove state recalculation from Frontend
- [ ] Add fallback empty transitions in StatusCatalog
- [ ] Document API contracts in OpenAPI/Swagger
- [ ] Add tests for state derivation determinism
- [ ] Consolidate ActivityStatus (Desktop) with operational_state
