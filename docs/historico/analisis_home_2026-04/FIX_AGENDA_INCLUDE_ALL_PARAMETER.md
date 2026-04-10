# FIX: Home vs Agenda Visibility Architecture Issue

## Problem
Users with COORDINATOR or SUPERVISOR roles couldn't see all activities in Agenda - only activities assigned to them. This is because the `/assignments` endpoint was called without the `include_all=true` parameter.

## Root Cause
1. **Backend design:** The `/assignments` endpoint accepts an optional `include_all` parameter
   - When `include_all=true`, privileged roles (COORD, SUPERVISOR, ADMIN) can see all activities
   - When `include_all=false` (default), all users see only activities assigned to them or created by them

2. **Mobile implementation gap:** The Agenda page never passed this parameter
   - AssignmentsRepository._defaultFetchAssignments() (line 199) only passed: project_id, from, to
   - Missing: include_all parameter

3. **Filtering logic difference:**
   - **Agenda** uses backend `/assignments` endpoint with filtering applied on server
   - **Home** uses `/sync/pull` endpoint with filtering applied on mobile client
   - This created inconsistent visibility

## Solution

### 1. Agenda Fix: Pass include_all=true Parameter
**File:** `lib/features/agenda/data/assignments_repository.dart` (lines 198-213)
**Change:** Add `'include_all': 'true'` to query parameters

```dart
queryParameters: {
  'project_id': projectId,
  'from': from.toIso8601String(),
  'to': to.toIso8601String(),
  'include_all': 'true', // ← NEW: Allow coordinators/supervisors to see all
},
```

**Rationale:**
- The backend's `user_has_any_role()` check will validate server-side whether the user should see all
- Coordinators (COORD) and Supervisors (SUPERVISOR) roles will be allowed to view all activities
- Operatives (OPERATIVO) will still only see activities assigned to them (due to backend filtering)
- This provides secure, role-based visibility control on the server

### 2. Home Page: Remains Using Sync Pull with Local Filtering
**File:** `lib/features/home/home_page.dart`
**Status:** Keep as-is for now
**Rationale:** Home page displays a personalized dashboard for the current user, so strict filtering is appropriate

**Note:** If admin/coordinators should see all activities in Home, a separate issue should be created to:
1. Add a toggle/view mode for "All Activities" vs "My Activities"
2. Or change the fallback logic to match Agenda's behavior

## Testing

**To verify the fix works:**

1. **Login as COORDINATOR role**
   - Open Agenda page
   - Navigate to a week with activities not directly assigned to the coordinator
   - Should now see those activities (because include_all=true allows it)
   - Backend validates the COORD role and allows visibility

2. **Login as OPERATIVO (operative) role**
   - Open Agenda page
   - Navigate to a week with activities not assigned to them
   - Should NOT see those activities (backend filtering still applies)

3. **Login as ADMIN role**
   - Open Agenda and Home
   - Should see all activities in both (Admin role has highest permissions)

4. **Verify different endpoints:**
   - Agenda: `/assignments?include_all=true` → Backend filtering based on role
   - Home: `/sync/pull` → Local filtering on mobile (no include_all parameter)

## Architecture Clarification

This fix clarifies the intended architecture:

| Feature | Endpoint | Filtering | Purpose |
|---------|----------|-----------|---------|
| **Agenda** | `/assignments?include_all=true` | Backend (role-based) | Team coordination view - see all activities |
| **Home** | `/sync/pull` | Mobile (local) | Personal dashboard - see relevant activities |

The `include_all` parameter enables:
- **Coordinators/Supervisors** to see the full picture of team assignments
- **Operatives** to maintain focus on their personal tasks
- **Backend validation** of roles to prevent unauthorized access
- **Security** by requiring explicit opt-in on the client side

## Rollout

1. ✅ Code fix applied to `assignments_repository.dart`
2. ⏳ Rebuild APK with `flutter build apk --release`
3. ⏳ Deploy to infrastructure (Cloud Run already has the fallback logic)
4. ⏳ Test with coordinator and operative accounts
5. ⏳ Document in release notes
