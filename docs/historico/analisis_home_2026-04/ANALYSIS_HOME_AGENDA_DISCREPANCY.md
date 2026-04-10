# HOME vs AGENDA Visibility Discrepancy Analysis

## Problem Statement
User reports: **"En agenda sí se ve la actividad asignada pero en home no"**
(In Agenda the assigned activity IS shown, but in Home NO)

## Data Flow Comparison

### AGENDA Data Path
```
Mobile App
  ↓
AssignmentsRepository.loadRange()
  ↓
GET /api/v1/assignments?project_id=TMQ&from=...&to=...
  (Note: NO include_all parameter passed)
  ↓
Backend filtering (assignments.py lines 220-224):
  - Loads all activities for project
  - Calculates effective_assignee = assigned_to_user_id OR created_by_user_id
  - Filters: IF (NOT can_view_all AND current_user_id AND effective_assignee ≠ current_user)
    → SKIP this activity
  - can_view_all = include_all AND user_has_any_role(...)
  - Since include_all is NOT passed → can_view_all = False
  ↓
Backend returns filtered list to mobile
  ↓
AgendaController._loadCurrentWeekAssignments()
  ↓
AgendaEquipoPage._filterItems() filtering by:
  - Date range (week view)
  - Selected filter chip (resource or "Todos")
  → NO user-based filtering (filters by resourceId if selected)
  ↓
Agenda UI displays result
```

### HOME Data Path
```
Mobile App
  ↓
home_page.dart._loadHomeActivities()
  ↓
SQL Query: ActivityDao.listHomeActivitiesByProject()
  ↓
Local filtering (home_page.dart lines 532-535):
  - IF (_isOperativeViewer)
    → WHERE assignedToUserId == currentUserId
    → Check: notNull AND notEmpty AND equals
  - ELSE show all
  ↓
Home UI displays result
```

## Key Difference: Backend Filtering vs Mobile Filtering

| Aspect | Agenda | Home |
|--------|--------|------|
| **Data Source** | `/assignments` endpoint | `/sync/pull` endpoint → SQLite |
| **Filtering Location** | Backend (server)| Mobile (client) |
| **Filter by User** | YES (via `can_view_all` flag) | YES (local strict equality) |
| **Fallback Logic** | `effective_assignee = assigned_to OR created_by` | No fallback - uses assigned_to only |
| **Backend Filtering** | `can_view_all=False` (because no `include_all`) | `/sync/pull` has no `can_view_all` logic |
| **Current Behavior** | Shows only activities where effective_assignee == current_user | Shows activities where assigned_to_user_id == current_user |

## Mystery: How is Activity Visible in Agenda?

Given the backend filtering logic, an activity should only appear in Agenda if:

1. **User is the Assignee**
   - `assigned_to_user_id == current_user_id` ✅ Shows in Agenda
   - `assigned_to_user_id == current_user_id` ✅ Shows in Home (if filter matches)

2. **User Created It (Fallback)**
   - `created_by_user_id == current_user_id` ✅ Shows in Agenda (via fallback)
   - `created_by_user_id == current_user_id` ❌ Does NOT show in Home (Home doesn't use fallback)

3. **include_all=true Passed (Currently NOT happening)**
   - Would make `can_view_all=True` ✅ Shows in Agenda
   - Not applicable to Home (uses sync/pull which has no such logic)

### HYPOTHESIS
The activity visible in Agenda might be one that the CURRENT USER CREATED but was assigned to someone else.
- Agenda shows it via fallback logic: `effective_assignee = assigned_to OR created_by`
- Home DOESN'T show it because it only checks `assignedToUserId` (no fallback)

## Test Scenario - Verify Which User is Logged In

To diagnose this issue, we need to verify:

1. **Which user is currently logged in?**
   - Is they admin? An operative? A coordinator?
   - Check: User profile in mobile app

2. **For the "Reunión" activity in TMQ:**
   - `assigned_to_user_id` = f5f92a1b-c9e2-482a-937b-317dccd9429e (Fernanda)
   - `created_by_user_id` = 090ac2e0-... (Admin)

3. **If logged in as Admin:**
   - Home should NOT show it (Admin ≠ assigned Fernanda)
   - But Agenda SHOULD show it (Admin = created_by)
   - ✅ This matches the user's report!

4. **If logged in as Fernanda:**
   - Home should SHOW it (Fernanda = assigned_to_user_id)
   - Agenda should SHOW it (Fernanda = assigned_to_user_id)
   - ❌ This does NOT match the report (Home should show)

5. **If logged in as Jesus (OPERATIVO):**
   - Home should NOT show it (Jesus ≠ assigned Fernanda)
   - Agenda should NOT show it (Jesus ≠ effective_assignee and no include_all)
   - ❌ This does NOT match the report (Agenda shows it)

## Root Cause Analysis - Most Likely Scenario

**Current logged-in user is likely Admin:**
- Admin created the "Reunión" activity
- Admin assigned it to Fernanda
- Backend fallback logic in `/assignments`: effective_assignee = assigned_to_user_id (Fernanda) OR created_by_user_id (Admin)
- Since assigned_to_user_id is Fernanda, effective_assignee = Fernanda
- But current_user = Admin
- Backend filter (line 224): Fernanda ≠ Admin → Should SKIP in both Agenda AND Home

**Wait, that still doesn't explain why it shows in Agenda but not Home...**

## Alternative: Check if include_all Parameter is Being Passed Somewhere

Search result: Mobile repo `assignments_repository.dart` (lines 202-203) calls `/assignments` endpoint **WITHOUT `include_all` parameter**.

**Possible Issue:** Maybe there's another code path that DOES pass `include_all=true`?

Let me check if Agenda uses a different code path when loading assignments...

## Action Items to Resolve

1. **Verify which user is logged in** when seeing the discrepancy
2. **Check if `/assignments` endpoint is being called with `include_all=true` somewhere**
3. **Check if Home and Agenda are using different data sources or caching**
4. **Verify that the latest APK has the updated filtering logic**
5. **Check if there's a race condition in sync (activities arriving at different times)**

## Conclusion

The discrepancy suggests one of:
1. **Different users logged in for Agenda vs Home** (unlikely)
2. **Different roles being evaluated** (Coordinator/Supervisor might have different filtering)
3. **The `/assignments` endpoint is being called with `include_all=true` somewhere** (but code review didn't find it)
4. **Local cache mismatch** between Agenda and Home data sources
5. **User confusion** - maybe they're looking at different time periods or projects

**NEXT STEP:** Get clarification from user on which user account is logged in when they see this behavior.
