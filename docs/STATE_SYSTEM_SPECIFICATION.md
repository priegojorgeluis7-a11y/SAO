# Especificación del sistema de estados - referencia unificada

## Resumen
Este documento funciona como fuente única de verdad para las definiciones de estado y sus mapeos entre backend y frontend en SAO.

---

## Estado de ejecución
**Propósito:** Estado principal que controla el ciclo de vida de la actividad; la app móvil lo actualiza.  
**Alcance:** Solo móvil puede modificar este valor.  
**Persistencia:** Firestore `activities.execution_state`

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

## Estado operativo  
**Propósito:** Estado normalizado para la lógica de interfaz; siempre se deriva.  
**Alcance:** Es de solo lectura en frontend y se recalcula en backend al leer.  
**Derivación:** `infer_operational_state(execution_state)`

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

## Estado de sincronización  
**Propósito:** Dar seguimiento al estado de sincronización con el servidor.  
**Alcance:** El frontend gestiona el ciclo de vida y el backend lo reporta al leer.  
**Persistencia:** La app móvil lo registra en SQLite `timeline_sync_status`

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

## Estado de revisión
**Propósito:** Reflejar la decisión del coordinador o supervisor.  
**Alcance:** Solo aplica cuando `execution_state` está en `REVISION_PENDIENTE` o `COMPLETADA`.  
**Derivación:** `infer_review_state(execution_state, review_decision)`

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

## Acción siguiente
**Propósito:** Sugerir al frontend la acción más conveniente para el usuario.  
**Alcance:** Es informativa; el frontend sigue controlando el flujo real.  
**Prioridad:** `review_state` > `sync_state` > `operational_state`

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

## Estado de actividad en escritorio
**Propósito:** Estados específicos del cliente desktop.  
**Alcance:** Solo escritorio; no lo usa móvil.  
**Valores:** `pendingReview`, `approved`, `rejected`, `needsFix`, `corrected`, `conflict`

**Nota:** Desktop debe mapearlos a `operational_state` y `review_state`.  
**Código:** `desktop_flutter/sao_desktop/lib/data/catalog/activity_status.dart`

**Nota de migración:** A futuro debe consolidarse con `operational_state`.

---

## Estados de interfaz
**Propósito:** Definir reglas de workflow y transiciones permitidas para la UI.  
**Alcance:** Frontend móvil y desktop.  
**Valores:** `borrador`, `nuevo`, `enRevision`, `requiereCambios`, `aprobado`, `rechazado`, `sincronizado`, `offline`, `conflicto`

**Código:** `frontend_flutter/sao_windows/lib/catalog/status_catalog.dart`

**Relación:** Se mapean desde `execution_state` hacia la presentación visual.  
**Fallback:** Si el workflow no existe en catálogo, debe devolverse una lista vacía o transiciones por defecto según política del cliente.

---

## Reglas de validación

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

## Contratos de API

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

## Constantes de referencia

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

## Solución de problemas

### "La actividad muestra distinto estado en Inicio y Agenda"
- **Causa probable:** Se están usando fuentes de datos diferentes, por ejemplo `sync/pull` contra `assignments`.
- **Inicio:** usa `/sync/pull` y filtrado local en SQLite.
- **Agenda:** usa `/assignments` y filtrado desde backend.

### "Los estados divergen entre backend y frontend"
- **Causa:** el frontend recalcula estados que ya vienen proyectados desde backend.
- **Solución:** consumir directamente los valores de la API y evitar duplicar la lógica.
- **Archivos a revisar:**
  - `frontend_flutter/sao_windows/lib/features/sync/services/sync_service.dart:816+`

### "Llegó un valor desconocido en sync_state"
- **Causa:** la API devolvió un valor fuera de `VALID_SYNC_STATES`.
- **Solución:** actualizar `VALID_SYNC_STATES` y `SyncStatusMapper`.
- **Fallback seguro:** tratarlo como `SYNCED` mientras se corrige el contrato.

### "La UI quedó bloqueada y no hay transiciones disponibles"
- **Causa:** `StatusCatalog.nextStatesFor()` devolvió una lista vacía.
- **Solución:** agregar transiciones de fallback o corregir el catálogo.
- **Valor seguro:** permitir `CANCELED` desde cualquier estado cuando aplique.

---

## Pendientes de implementación

- [ ] Asegurar respuestas API con valores consistentes.
- [ ] Agregar un `SyncStatusMapper` explícito para todas las conversiones backend a frontend.
- [ ] Eliminar recálculos redundantes de estado en frontend.
- [ ] Definir transiciones de respaldo en `StatusCatalog`.
- [ ] Documentar contratos en OpenAPI o Swagger.
- [ ] Añadir pruebas de determinismo para derivación de estados.
- [ ] Consolidar `ActivityStatus` de escritorio con `operational_state`.
