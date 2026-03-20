# Code Audit - 2026-03-09

## Scope
- Frontend:
  - `frontend_flutter/sao_windows/lib/features/admin/admin_activity_history.dart`
  - `frontend_flutter/sao_windows/lib/features/admin/admin_activity_detail.dart`
  - `frontend_flutter/sao_windows/lib/catalog/roles_catalog.dart`
- Backend:
  - `backend/app/api/v1/assignments.py`

## Findings

### 1) High - Authorization mismatch allows UI action that backend rejects
- Evidence:
  - Frontend maps `SUPERVISOR` to `coordinador` in permission resolution: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_detail.dart:75`
  - Frontend grants cancel button based on `RolesCatalog.permDeleteActivity`: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_detail.dart:28`, `frontend_flutter/sao_windows/lib/features/admin/admin_activity_detail.dart:210`
  - Backend cancel endpoint only allows `ADMIN` and `COORD`: `backend/app/api/v1/assignments.py:200`
- Impact:
  - A `SUPERVISOR` can see/enabled cancel action in UI but gets 403 from backend.
  - Produces broken UX and role policy inconsistency.
- Recommendation:
  - Align role contract in one of these ways:
    - Include `SUPERVISOR` in backend guard if business rules allow it.
    - Or remove `SUPERVISOR -> coordinador` mapping in frontend cancel eligibility.
  - Add integration tests for cancel action per role matrix (`ADMIN`, `COORD`, `SUPERVISOR`, `OPERATIVO`).

### 2) High - Cancel permission is not scoped to the activity project
- Evidence:
  - Frontend permission resolver aggregates all roles from `/me/projects` and applies `any(...)` globally: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_detail.dart:28-58`
- Impact:
  - User with admin/coordinator in Project A and low privileges in Project B may still see cancel action when viewing a Project B activity.
  - Creates over-permission in UI and authorization confusion.
- Recommendation:
  - Resolve permission by activity project scope (project of `activityId`), not global role union.
  - Pass project context into detail page and filter `role_names` by matching project before evaluating permissions.

### 3) High - Identifier contract mismatch in admin history -> detail -> cancel flow
- Evidence:
  - History list uses mock labels as IDs: `List.generate(10, (i) => 'Actividad ${i + 1}')`: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_history.dart:126`
  - Those labels are passed as `activityId` into detail page: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_history.dart:140`
  - Detail page sends that value to UUID endpoint `/assignments/{assignment_id}/cancel`: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_detail.dart:91`
  - Backend expects UUID type: `backend/app/api/v1/assignments.py:199`
- Impact:
  - Current flow can produce 422 validation failures in cancel endpoint.
  - Blocks real operation and hides true backend behavior under mock path.
- Recommendation:
  - Use real assignment UUID in history data model and route args.
  - Add frontend guard for invalid IDs before POST and surface explicit error message.

### 4) Medium - Admin history/detail remain mostly mock and non-functional
- Evidence:
  - Explicit TODO for real data in history: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_history.dart:125`
  - Explicit TODO for real data in detail: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_detail.dart:110`
  - Static metrics and no-op filters (`onChanged: (v) {}`): `frontend_flutter/sao_windows/lib/features/admin/admin_activity_history.dart:63`, `frontend_flutter/sao_windows/lib/features/admin/admin_activity_history.dart:74`
  - Export is placeholder snackbar: `frontend_flutter/sao_windows/lib/features/admin/admin_activity_history.dart:33`
- Impact:
  - UI suggests production capability but does not represent real operational data.
  - Increases risk of false confidence during demos/UAT.
- Recommendation:
  - Wire both pages to backend list/detail endpoints and remove mock literals.
  - Keep placeholders behind explicit feature flags if needed.

### 5) Medium - Cancel endpoint lacks cancellation audit metadata
- Evidence:
  - Endpoint unassigns and resets state (`assigned_to_user_id = None`, `execution_state = "PENDIENTE"`) without reason/comment/by-user fields in response or persisted metadata: `backend/app/api/v1/assignments.py:221-222`
- Impact:
  - Limited traceability for who cancelled and why.
  - Harder incident analysis and compliance auditing.
- Recommendation:
  - Add cancellation audit fields (`canceled_by_user_id`, `canceled_at`, `cancel_reason`) either on activity or dedicated audit table.
  - Include these in API response and logs.

## Positive Notes
- Backend authorization exists for cancel endpoint and blocks unauthorized roles by default: `backend/app/api/v1/assignments.py:200`.
- Cancel operation increments `sync_version`, which helps downstream sync consistency: `backend/app/api/v1/assignments.py:219-223`.

## Testing Gaps
- Missing end-to-end tests for `history -> detail -> cancel` using real UUIDs.
- Missing role-matrix tests comparing frontend button visibility vs backend authorization behavior.
- Missing project-scope authorization tests (role in one project should not grant action in another).

## Suggested Priority Plan
1. Fix role contract mismatch (`SUPERVISOR` handling) and add role-matrix tests.
2. Scope frontend permission check by activity project.
3. Replace mock IDs/data with real assignment data in admin history/detail.
4. Add cancellation audit metadata and expose in detail timeline.
