# BEST PRACTICES: State Management in SAO

## Core Principle: Trust Backend Derivations

**Rule #1: Don't Recalculate States**  
Backend provides derived states (operational_state, review_state, sync_state, next_action).  
Frontend should **trust these values** unless there's a clear edge case.

```dart
// ✅ CORRECT: Use backend-provided states
final operationalState = dto.operationalState;  // From Backend
final reviewState = dto.reviewState;            // From Backend
final syncState = dto.syncState;                // From Backend

// ❌ WRONG: Recalculating in Frontend
final operationalState = inferOperationalState(dto.executionState);
final reviewState = inferReviewState(dto.executionState, dto.reviewDecision);
```

**Why?**
- Backend has all the data (Firestore, audit trail, permissions)
- Frontend doesn't have context for all edge cases
- If Backend logic changes, mobile doesn't need redeploy
- Reduces bugs from state divergence

---

## State Flow Architecture

### 1. Data Flows from Backend → Frontend (One Direction)
```
Backend (Firestore)
    ↓
[Derive: operational_state, review_state, sync_state, next_action]
    ↓
API Response (ActivityDTO, SyncResponse)
    ↓
Frontend (SQLite, Memory, UI)
    ↓
Display/Use
```

### 2. What Frontend SHOULD Do
```dart
// When you receive DTO from API:
Future<void> _processActivityFromSync(ActivityDTO dto) {
  // 1. Accept backend-derived values as truth
  final status = dto.operationalState;        // ✅ Trust this
  final reviewStatus = dto.reviewState;       // ✅ Trust this
  final syncStatus = dto.syncState;           // ✅ Trust this
  
  // 2. Store all values (for accurate UI display)
  await db.activities.insert(ActivitysCompanion(
    operationalState: Value(status),
    reviewState: Value(reviewStatus),
    syncState: Value(syncStatus),
    nextAction: Value(dto.nextAction),
  ));
  
  // 3. Calculate ONLY composite local-status for quick queries
  // (Not recalculation of backend logic, just mapping to local DB schema)
  final localStatus = _computeDisplayStatus(
    operationalState: status,
    reviewState: reviewStatus,
    syncState: syncStatus,
  );
  await db.activities.update().replace(
    ActivitysCompanion(status: Value(localStatus))
  );
}
```

### 3. When to Use Local Calculation
Only calculate locally when:
1. **Offline mode**: No Backend available  (use last-known-server-state as fallback)
2. **Composite display status**: Combining multiple server-states for UI visualization
3. **Edge cases**: When you've lost server connection mid-transaction

**NOT** for recalculating what Server already derived.

---

## Example: Activity Status Display

### Before (Wrong - Recalculation)
```dart
// From Server
final dto = ActivityDTO(
  executionState: 'COMPLETADA',
  operationalState: 'POR_COMPLETAR',
  reviewState: 'PENDING_REVIEW',
  syncState: 'SYNCED',
);

// Frontend recalculates (BUG!)
String status = inferOperationalState(dto.executionState);  // ❌ Duplicates Backend logic
```

### After (Correct - Trust)
```dart
// From Server
final dto = ActivityDTO(
  executionState: 'COMPLETADA',
  operationalState: 'POR_COMPLETAR',   // ← Already derived by Backend
  reviewState: 'PENDING_REVIEW',        // ← Already derived by Backend
  syncState: 'SYNCED',                  // ← Already derived by Backend
);

// Frontend uses directly (✅)
String displayStatus = dto.operationalState;  // = 'POR_COMPLETAR'
String nextAction = dto.nextAction;           // = 'COMPLETAR_WIZARD'

// Store in DB
await db.activities.insert(ActivitysCompanion(
  operationalState: Value(dto.operationalState),
  reviewState: Value(dto.reviewState),
  syncState: Value(dto.syncState),
));

// If needed for UI, map to display string
String label = _statusLabels[dto.operationalState] ?? 'Desconocido';  // "Requiere completar"
```

---

## Sync State Mapping

### Converting Backend → Frontend Enum
Use `SyncStatusMapper` instead of manual logic:

```dart
// ✅ CORRECT
import 'path/to/sync_status_mapper.dart';

final frontendStatus = SyncStatusMapper.fromBackend(dto.syncState);
// Input: "READY_TO_SYNC" → Output: SyncStatus.pending
// Input: "SYNC_IN_PROGRESS" → Output: SyncStatus.uploading
// Input: "SYNCED" → Output: SyncStatus.synced
// Input: "SYNC_ERROR" → Output: SyncStatus.error

// ❌ WRONG
enum SyncStatus { pending, uploading, synced, error }
final status = switch(dto.syncState) {
  'LOCAL_ONLY' => SyncStatus.pending,
  'READY_TO_SYNC' => SyncStatus.pending,
  // ... duplicated across the codebase
};
```

---

## Review State Handling

### Backend Always Returns English
```json
{
  "review_state": "PENDING_REVIEW",  // ← Always English (API contract)
  "review_decision": "REQUEST_CHANGES"
}
```

### Frontend Translates for Display
```dart
// ✅ Store backend value as-is
final reviewState = dto.reviewState;  // "PENDING_REVIEW"

// For UI display, translate:
String getReviewLabel(String reviewState) {
  return {
    'NOT_APPLICABLE': 'No requiere revisión',
    'PENDING_REVIEW': 'Pendiente de revisión',
    'CHANGES_REQUIRED': 'Cambios requeridos',
    'APPROVED': 'Aprobada',
    'REJECTED': 'Rechazada',
  }[reviewState] ?? 'Desconocido';
}

Text(getReviewLabel(reviewState));
```

**NOT:**
```dart
// ❌ WRONG: Hardcoding Spanish in logic
if (reviewState == 'PENDIENTE_REVISION') {  // ← Wrong, backend doesn't return this
  ...
}
```

---

## Safe Fallbacks (When Needed)

If you MUST recalculate locally (offline mode):

```dart
/// Only use for offline fallback, not as primary logic.
String _inferOperationalStateOffline(String executionState) {
  return switch(executionState.toUpperCase()) {
    'PENDIENTE' => 'PENDIENTE',
    'EN_CURSO' => 'EN_CURSO',
    'REVISION_PENDIENTE' || 'COMPLETADA' => 'POR_COMPLETAR',
    'CANCELED' => 'CANCELADA',
    _ => 'PENDIENTE',
  };
}

// Use only if server value unavailable:
final status = dto.operationalState.isNotEmpty
    ? dto.operationalState  // ✅ Prefer server
    : _inferOperationalStateOffline(dto.executionState);  // 🟡 Fallback only
```

---

## Testing & Validation

### Unit Tests: Verify Backend Derivations
```dart
test('Backend operationalState derivation is deterministic', () {
  final dto1 = ActivityDTO(executionState: 'COMPLETADA', ...);
  final dto2 = ActivityDTO(executionState: 'COMPLETADA', ...);
  
  // Both should have the same derived operationalState
  expect(dto1.operationalState, equals(dto2.operationalState));
});

test('Frontend respects backend-derived states', () {
  final dto = ActivityDTO(
    executionState: 'EN_CURSO',
    operationalState: 'EN_CURSO',  // Backend-derived
  );
  
  // Frontend should use dto.operationalState directly
  final activity = Activity.fromDTO(dto);
  expect(activity.status, equals('EN_CURSO'));
  // NOT expect(activity.status, equals(recalculateLocally(...)));
});
```

### Integration Tests: End-to-End State Flow
```dart
test('Activity state flows correctly from server to UI', () async {
  // 1. Setup: Server has activity with derived states
  final serverActivity = {
    'execution_state': 'COMPLETADA',
    'operational_state': 'POR_COMPLETAR',  ← Server-derived
    'review_state': 'PENDING_REVIEW',      ← Server-derived
    'sync_state': 'SYNCED',                ← Server-derived
    'next_action': 'COMPLETAR_WIZARD',     ← Server-derived
  };
  
  // 2. Action: Sync pull brings it to frontend
  final dto = ActivityDTO.fromJson(serverActivity);
  await sync.processPullResponse(dto);
  
  // 3. Verify: Frontend UI shows correct state
  final displayed = await getDisplayedStatus(dto.id);
  expect(displayed, equals('Requiere completar')); // Maps to operationalState
  
  // 4. Important: Verify NO recalculation happened
  final stored = await db.activities.findById(dto.id);
  expect(stored.operationalState, equals('POR_COMPLETAR'));
  // If we recalculated, this might differ if our logic is slightly different!
});
```

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Trusting Cached Value When Server Changed
```dart
// BAD
final cachedStatus = _lastKnownStatus;
if (cachedStatus.isNotEmpty) {
  return cachedStatus;  // What if server changed it?
}
final serverStatus = await api.getStatus();
```

**Better:**
```dart
// GOOD: Always use latest from server
final serverStatus = await api.getStatus();
_cache = serverStatus;
return serverStatus;
```

### ❌ Mistake 2: Different Logic in Frontend vs Backend
```dart
// Backend:
if (executionState == 'COMPLETADA') {
  operationalState = 'POR_COMPLETAR';
}

// Frontend (WRONG - slightly different):
if (executionState == 'COMPLETADA' || dto.formFilled) {
  operationalState = 'READY';
}
// Now they diverge!
```

**Better:**
```dart
// Frontend: Just trust the backend value
final operationalState = dto.operationalState;
```

### ❌ Mistake 3: Assuming All States Are Persisted
```dart
// WRONG: What if the server doesn't send it?
final review = serverDTO.reviewState ?? inferLocally(...);

// BETTER: Add validation
if (reviewState.isEmpty) {
  log.error('Missing review_state in API response');
  throw StateException('Invalid server response');
}
```

---

## Monitoring & Debugging

### Log State Divergence
```dart
void _trackStateChanges(ActivityDTO before, ActivityDTO after) {
  if (before.operationalState != after.operationalState) {
    analytics.log('operational_state_changed', {
      'before': before.operationalState,
      'after': after.operationalState,
      'execution_state': after.executionState,
      'source': 'backend',  // Explicitly mark it came from backend
    });
  }
}
```

### Detect Recalculation Bugs
```dart
void _detectLocalRecalculation() {
  final serverState = dto.operationalState;
  final localCalculated = inferOperationalState(dto.executionState);
  
  if (serverState != localCalculated) {
    log.warn('State divergence detected!', {
      'server': serverState,
      'local_calc': localCalculated,
      'execution': dto.executionState,
      'risk': 'UI showing wrong status',
    });
  }
}
```

---

## Summary Checklist

✅ **DO:**
- [x] Trust backend-derived states (operational_state, review_state, sync_state, next_action)
- [x] Store all states in local DB for accurate display
- [x] Use SyncStatusMapper for enum conversion
- [x] Translate review_state to Spanish for display only
- [x] Document why you're NOT recalculating
- [x] Write tests that verify backend derivation is used
- [x] Log state divergences for debugging

❌ **DON'T:**
- [ ] Recalculate operationalState from executionState
- [ ] Recalculate reviewState from reviewDecision
- [ ] Hardcode Spanish status strings in logic
- [ ] Assume offline = permission to recalculate
- [ ] Duplicate Backend derivation logic in Frontend
- [ ] Compare old and new states manually in business logic

---

## Migration Path (For Existing Code)

If you have existing code that recalculates:

### Step 1: Identify Recalculation Sites
```bash
grep -r "infer.*State\|derive.*\|switch.*execution" \
  lib/features/*/
```

### Step 2: Replace with Backend Values
```dart
// BEFORE
final status = inferOperationalState(dto.executionState);

// AFTER
final status = dto.operationalState;  // From backend
```

### Step 3: Add Test
```dart
test('Uses backend operational_state, not local inference', () {
  final dto = ActivityDTO(
    executionState: 'EN_CURSO',
    operationalState: 'EN_CURSO',  // Server-derived
  );
  final activity = Activity.fromDTO(dto);
  expect(activity.status, equals(dto.operationalState));
});
```

### Step 4: Deploy & Monitor
- Monitor for state divergence warnings
- Check analytics for changes in user-visible status
- Validate Home/Agenda visibility improvements

---

## References

- [STATE_SYSTEM_SPECIFICATION.md](../docs/STATE_SYSTEM_SPECIFICATION.md) - Complete state definitions
- [SyncStatusMapper](./sync_status_mapper.dart) - Enum conversion utility
- Backend: `backend/app/schemas/activity.py` - Derivation logic
- Frontend: `lib/features/sync/services/sync_service.dart` - Sync processing
