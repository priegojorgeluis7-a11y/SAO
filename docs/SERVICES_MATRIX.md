# SAO — Matriz de Servicios
**Fecha:** 2026-03-04 | Fuente: scan automatizado del repositorio

Leyenda: ✅ OK · 🟡 PARCIAL · ❌ FALTA

---

## Auth & Sesión

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Login (email+password) | ✅ `POST /auth/login` | ✅ `auth_repository.dart` | ✅ `app_session_controller.dart` | ✅ OK | - | JWT access+refresh |
| Registro / Signup | ✅ `POST /auth/signup` | ✅ `signup_page.dart` | ❌ FALTA | 🟡 PARCIAL | Roles hardcoded en signup_page | Desktop sin registro |
| Refresh token | ✅ `POST /auth/refresh` | ✅ `api_client.dart` auto-refresh | ❌ Sin auto-refresh | 🟡 PARCIAL | `backend_api_client.dart` sin interceptor JWT | Desktop: token en memoria, sin refresh |
| Perfil actual (`/me`) | ✅ `GET /auth/me` | ✅ `auth_repository.dart` | ✅ `app_session_controller.dart` | ✅ OK | - | - |
| Logout | ✅ `POST /auth/logout` | ✅ | ✅ | ✅ OK | - | - |
| PIN offline | ❌ FALTA flujo | ❌ FALTA implementación | N/A | ❌ FALTA | `pin_hash` en modelo User existe | Requerimiento operativo crítico |
| Roles disponibles (API) | ❌ FALTA endpoint | ❌ Hardcoded en signup | N/A | ❌ FALTA | `signup_page.dart:33-39` | Roles deben venir del backend |
| RBAC permisos | ✅ `require_permission()` + `require_any_role()` | 🟡 Solo usa token | 🟡 Solo usa rol string | 🟡 PARCIAL | `deps.py` | Mobile/Desktop no verifican permisos localmente |

---

## Catálogo (Bundle)

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Bundle actual | ✅ `GET /catalog/bundle` | ✅ `catalog_repository.dart` | ✅ `catalog_repository.dart` | ✅ OK | Con fallback a `base_seed_catalog.bundle.json` | |
| Versión actual | ✅ `GET /catalog/version/current` | 🟡 Solo en check-updates | 🟡 No implementado | 🟡 PARCIAL | - | |
| Check updates | ✅ `GET /catalog/check-updates` | 🟡 Sin uso activo | ❌ FALTA | 🟡 PARCIAL | `catalog_repository.dart` | No hay polling en background |
| Diff incremental | ✅ `GET /catalog/diff` | ❌ FALTA (carga bundle completo) | ❌ FALTA | ❌ FALTA | `catalog_repository.dart:49-86` | Mayor consumo de red |
| Listar versiones | ✅ `GET /catalog/versions` | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | Solo admin |
| Publicar versión | ✅ `POST /catalog/publish` | N/A | ❌ Sin UI | 🟡 PARCIAL | `catalog_editor_service.py` | Endpoint existe |
| Rollback | ✅ `POST /catalog/rollback` | N/A | ❌ Sin UI | 🟡 PARCIAL | - | Endpoint existe |
| Validate | ✅ `POST /catalog/validate` | N/A | ❌ Sin UI | 🟡 PARCIAL | - | Endpoint existe |
| Editor CRUD (actividades/subcats/propósitos/temas) | ✅ 10+ endpoints | N/A | ❌ Sin pantalla conectada | 🟡 PARCIAL | `catalog_editor_service.py` | Backend completo; desktop sin UI |
| Reorder | ✅ `POST /catalog/editor/reorder` | N/A | ❌ FALTA | ❌ FALTA | - | |
| Project ops (overrides) | ✅ `PATCH /catalog/project-ops` | ❌ FALTA | ❌ FALTA | ❌ FALTA | `catalog_bundle_service.py` | Overrides por proyecto |
| Catalog-driven form colors | N/A | ❌ Colors hardcoded en `activity_catalog.dart` | ❌ Colors en `status_catalog.dart` | ❌ FALTA | `AUDIT_REPORT.md §1.2` | Debe venir del bundle |
| Workflow state machine desde API | ❌ FALTA endpoint | ❌ Hardcoded `status_catalog.dart` | ❌ Hardcoded `status_catalog.dart` | ❌ FALTA | - | Agregar `GET /catalog/workflow` |

---

## Proyectos

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Listar proyectos | ✅ `GET /projects` (ADMIN/SUPERVISOR) | ❌ FALTA | ✅ `admin_repositories.dart` | 🟡 PARCIAL | `reports_provider.dart:70` | Mobile sin selector de proyecto |
| Crear proyecto | ✅ `POST /projects` (ADMIN) | N/A | ✅ `admin_repositories.dart` | ✅ OK | - | Con `bootstrap_from_tmq` |
| Actualizar proyecto | ✅ `PUT /projects/{id}` | N/A | ✅ | ✅ OK | - | |
| Eliminar proyecto | ✅ `DELETE /projects/{id}` | N/A | ✅ | ✅ OK | - | |
| Fronts de proyecto | ❌ FALTA endpoint | ❌ FALTA | ❌ FALTA | ❌ FALTA | Model `Front` existe | Necesario para scope RBAC |
| Locations de frente | ❌ FALTA endpoint | ❌ FALTA | ❌ FALTA | ❌ FALTA | Model `Location` existe | Necesario para scope RBAC |

---

## Actividades / Workflow

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Crear actividad | ✅ `POST /activities` | ✅ Wizard → SyncQueue → push | N/A | ✅ OK | Idempotente por UUID | |
| Listar actividades | ✅ `GET /activities` | ✅ Drift local | ✅ Via review queue | ✅ OK | - | |
| Obtener actividad | ✅ `GET /activities/{uuid}` | ✅ | ✅ | ✅ OK | - | |
| Actualizar actividad | ✅ `PUT /activities/{uuid}` | ✅ | N/A | ✅ OK | - | |
| Eliminar (soft delete) | ✅ `DELETE /activities/{uuid}` | ✅ | N/A | ✅ OK | - | |
| Submit para revisión | 🟡 Via status update | ✅ `READY_TO_SYNC` → push | N/A | 🟡 PARCIAL | No endpoint dedicado submit | Status change implícito en push |
| Approve (coordinador) | ✅ `POST /review/activity/{id}/decision` (approved) | N/A | ✅ `activity_repository.dart:424` | ✅ OK | - | |
| Reject (coordinador) | ✅ `POST /review/activity/{id}/decision` (rejected) | N/A | ✅ `activity_repository.dart:463` | ✅ OK | - | |
| Request changes | ✅ `POST /review/activity/{id}/decision` (changes_required) | N/A | ✅ `activity_repository.dart:502` | ✅ OK | - | |
| Approve exception (ADMIN) | ✅ APPROVE_EXCEPTION | N/A | ❌ Sin UI | 🟡 PARCIAL | `review.py` | |
| Triage / Queue | ✅ `GET /review/queue` | N/A | ✅ `dashboard_provider.dart:54` | ✅ OK | - | |
| Timeline / historial | ❌ FALTA endpoint | ❌ `ActivityLog` local | ❌ FALTA | ❌ FALTA | `tables.dart: ActivityLog` | No expuesto en API |
| Reject playbook | ✅ `GET /review/reject-playbook` | N/A | ✅ `activity_repository.dart:48` | ✅ OK | Razones hardcoded backend | |
| Activity flags estructurados (gps/catalog) | ❌ FALTA campo | ❌ FALTA | ❌ Text matching | ❌ FALTA | `AUDIT_REPORT.md §1.4` | |

---

## Sync

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Push activities | ✅ `POST /sync/push` | ✅ `sync_service.dart` | N/A | ✅ OK | Auto-sync 15min | |
| Pull activities (cursor) | ✅ `POST /sync/pull` | ❌ Orquestador existe sin implementar pull real | N/A | 🟡 PARCIAL | `sync_orchestrator.dart` | Solo outbound actualmente |
| Push events | ✅ `POST /events/{uuid}` idempotente | ✅ `sync_service.dart:65` | N/A | ✅ OK | - | |
| Pull events | ❌ No existe pull events endpoint | ❌ FALTA | N/A | ❌ FALTA | `events.py` solo GET paginado | |
| Outbox queue | N/A | ✅ `SyncQueue` Drift table | ❌ FALTA | 🟡 PARCIAL | Mobile: completo; Desktop: sin offline | |
| Cursor / since_version | ✅ En sync/pull | ❌ No usa cursor en pull | N/A | 🟡 PARCIAL | - | |
| Conflict detection | ✅ Retorna `CONFLICT` en push | ❌ Marca como ERROR sin UI | N/A | 🟡 PARCIAL | `tables.dart: SyncQueue` | |
| Conflict resolution UI | N/A | ❌ FALTA | N/A | ❌ FALTA | - | Pendiente prioridad alta |
| Auto-sync connectivity | N/A | ✅ `auto_sync_service.dart` | N/A | ✅ OK | Timer 15min + reconnect | |
| Catalog pull/diff | ✅ `/catalog/diff` existe | ❌ Carga bundle completo | N/A | 🟡 PARCIAL | `catalog_repository.dart:49-86` | |
| Evidence upload presign | ✅ `POST /evidences/upload-init` | ✅ `PendingUploads` table | N/A | ✅ OK | GCS signed URL 15min | |
| Evidence upload complete | ✅ `POST /evidences/upload-complete` | ✅ | N/A | ✅ OK | - | |
| Evidence retry | N/A | ✅ `PendingUploads.nextRetryAt` | N/A | ✅ OK | - | |

---

## Evidencias

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Presign upload | ✅ `POST /evidences/upload-init` | ✅ | N/A | ✅ OK | GCS | |
| Confirm upload | ✅ `POST /evidences/upload-complete` | ✅ | N/A | ✅ OK | - | |
| Download URL | ✅ `GET /evidences/{id}/download-url` | ✅ `sao_evidence_gallery.dart` | ✅ `evidence_gallery_panel_pro.dart` | ✅ OK | - | |
| Validar evidencia (review) | ✅ `POST /review/evidence/{id}/validate` | N/A | ✅ | ✅ OK | - | |
| Patch evidencia (review) | ✅ `PATCH /review/evidence/{id}` | N/A | ✅ | ✅ OK | - | |
| Caption editor | N/A | ✅ `caption_editor_widget.dart` | ✅ `caption_editor_widget.dart` | ✅ OK | - | |
| Listar evidencias de actividad | ✅ `GET /review/activity/{id}/evidences` | ✅ Drift local | ✅ | ✅ OK | - | |

---

## Eventos

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Crear evento | ✅ `POST /events` | ✅ `report_event_sheet.dart` | ❌ FALTA | 🟡 PARCIAL | - | Desktop sin UI de eventos |
| Listar eventos | ✅ `GET /events` | ❌ Sin pantalla de lista | ❌ FALTA | ❌ FALTA | `home_page.dart` solo tiene FAB | |
| Obtener evento | ✅ `GET /events/{uuid}` | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | |
| Actualizar evento | ✅ `PUT /events/{uuid}` | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | |
| Eliminar evento | ✅ `DELETE /events/{uuid}` | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | |
| Pull sync eventos | ❌ No endpoint pull | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | |

---

## Usuarios / RBAC

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Listar usuarios | ✅ `GET /users` | ❌ FALTA | ✅ `users_page.dart` | 🟡 PARCIAL | - | |
| Admin listar usuarios | ✅ `GET /users/admin` | N/A | ✅ `admin_repositories.dart` | ✅ OK | Req ADMIN/SUPERVISOR | |
| Crear admin user | ✅ `POST /users/admin` | N/A | ✅ | ✅ OK | Req ADMIN | |
| Actualizar admin user | ✅ `PATCH /users/admin/{id}` | N/A | ✅ | ✅ OK | - | |
| Asignaciones | ✅ `GET /assignments` | ❌ Sin pantalla de asignaciones | ✅ `assignments_repository.dart` | 🟡 PARCIAL | - | |
| Scope fronts/locations | ❌ Sin endpoints | ❌ FALTA | ❌ FALTA | ❌ FALTA | Models existen | |

## Índices Firestore

Ver inventario completo, estados y runbook de rollout/rollback en:
- [docs/FIRESTORE_INDEXES.md](FIRESTORE_INDEXES.md) — índices compuestos requeridos por colección
- [docs/RUNBOOK_CLOUD_RUN.md §13](RUNBOOK_CLOUD_RUN.md) — procedimiento de creación y rollback

---

## Observaciones

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Crear observación | ✅ `POST /observations` | ❌ FALTA | ❌ FALTA | ❌ FALTA | `observations.py` | Sin prefijo `/api/v1` en ruta actual |
| Listar observaciones | ✅ `GET /mobile/observations` | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | |
| Resolver observación | ✅ `POST /mobile/observations/{id}/resolve` | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | |

---

## Auditoría / Reports

| Feature / Servicio | Backend | Mobile | Desktop | Estado | Evidencia | Notas |
|-------------------|---------|--------|---------|--------|-----------|-------|
| Audit logs | ✅ `GET /audit` | N/A | ✅ `admin_repositories.dart` | ✅ OK | Max 500 rows | |
| Reports dashboard | N/A | N/A | 🟡 UI sin datos reales | 🟡 PARCIAL | `reports_page.dart` | Proyectos hardcoded |
| Export/PDF | ❌ FALTA | ❌ FALTA | ❌ FALTA | ❌ FALTA | - | No existe endpoint |

---

## Resumen Ejecutivo

| Capa | OK | PARCIAL | FALTA |
|------|-----|---------|-------|
| **Backend** | 42 | 8 | 9 |
| **Mobile** | 18 | 10 | 22 |
| **Desktop** | 15 | 8 | 20 |

**Críticos inmediatos:**
1. Pull sync mobile → backend (actividades)
2. Project context dinámico en desktop (7 archivos con 'TMQ' hardcoded)
3. PIN offline mobile
4. Endpoints fronts/locations
5. Catalog-driven workflow (status_catalog.dart hardcoded)
6. Prefijo `/api/v1` faltante en observations.py
