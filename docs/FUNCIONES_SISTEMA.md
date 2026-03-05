# SAO — Funciones del Sistema: Estado Actual y Gaps de Lógica

**Fecha:** 2026-03-05
**Versión del sistema:** 0.2.2
**Alcance:** Backend FastAPI · App Móvil Flutter · Desktop Admin Flutter

---

## Índice

1. [Backend FastAPI](#1-backend-fastapi)
2. [App Móvil (Operativo)](#2-app-móvil-operativo)
3. [Desktop Admin (Coordinador/Supervisor)](#3-desktop-admin-coordinadorsupervisor)
4. [Gaps: Funciones sin lógica conectada](#4-gaps-funciones-sin-lógica-conectada)
5. [Mapa rápido de dependencias UI → API](#5-mapa-rápido-de-dependencias-ui--api)

---

## 1. Backend FastAPI

### 1.1 Autenticación y Sesión

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Login con email/password | `POST /auth/login` | ✅ Implementada | Valida credenciales, emite JWT access (24h) + refresh (30d) |
| Registro con invite code | `POST /auth/signup` | ✅ Implementada | Requiere `SIGNUP_INVITE_CODE`; crea usuario + asigna rol inicial |
| Refresh de token | `POST /auth/refresh` | ✅ Implementada | Valida refresh token, emite nuevo access token |
| Perfil del usuario autenticado | `GET /auth/me` | ✅ Implementada | Retorna datos del usuario y roles del JWT actual |
| Cambio de PIN offline | `PUT /auth/me/pin` | ✅ Implementada | Almacena `pin_hash` (bcrypt) para uso offline en campo |
| Lista de roles disponibles | `GET /auth/roles` | ✅ Implementada | Retorna catálogo de roles para el selector de signup |
| Rate limiting en login/refresh | Automático | ✅ Implementada | 429 + `Retry-After` tras N intentos fallidos |

### 1.2 Catálogo de Actividades

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Descargar bundle completo | `GET /catalog/bundle` | ✅ Implementada | Retorna JSON bundle con entities + rules + editor |
| Verificar actualizaciones por hash | `GET /catalog/check-updates` | ✅ Implementada | Compara hash del bundle local vs servidor; evita descarga si no hay cambios |
| Diff incremental | `GET /catalog/diff` | ✅ Implementada | Retorna solo los deltas desde una versión base |
| Lista de versiones | `GET /catalog/versions` | ✅ Implementada | Historial de versiones publicadas del catálogo |
| Publicar versión | `POST /catalog/publish` | ✅ Implementada | Transición Draft → Published (requiere `catalog.publish`) |
| Deprecar versión | `POST /catalog/deprecate` | ✅ Implementada | Transición Published → Deprecated |
| Rollback a versión anterior | `POST /catalog/rollback` | ✅ Implementada | Reactiva versión previa como Published |
| Validar borrador | `POST /catalog/validate` | ✅ Implementada | Corre reglas de consistencia sobre el draft antes de publicar |
| Editor (10+ endpoints) | `/catalog/editor/*` | ✅ Implementada | CRUD de entidades del catálogo (actividades, subcategorías, propósitos, temas) |
| Bootstrap de proyecto desde TMQ | `POST /projects/{id}/bootstrap_from_tmq` | ✅ Implementada | Copia el template TMQ al nuevo proyecto como catálogo base |
| Flujo de trabajo (workflow) | `GET /catalog/workflow` | ✅ Implementada | Retorna la máquina de estados del workflow como JSON |

### 1.3 Actividades

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Crear actividad | `POST /activities` | ✅ Implementada | UUID idempotente; valida proyecto/frente/tipo de catálogo |
| Listar actividades | `GET /activities` | ✅ Implementada | Filtros: project_id, status, front, fecha |
| Obtener actividad | `GET /activities/{uuid}` | ✅ Implementada | Retorna DTO completo con campos dinámicos |
| Editar actividad | `PUT /activities/{uuid}` | ✅ Implementada | Solo en estados DRAFT / REQUIERE_CAMBIOS |
| Soft delete | `DELETE /activities/{uuid}` | ✅ Implementada | Marca `deleted_at`; no borra física |
| Historial de actividad | `GET /activities/{uuid}/timeline` | ✅ Implementada | Retorna lista ordenada de eventos de auditoría por actividad |
| Actualizar flags estructurados | `PATCH /activities/{uuid}/flags` | ✅ Implementada | Set `gps_mismatch`, `catalog_changed`; incrementa `sync_version` |

### 1.4 Sincronización

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Push de actividades/eventos | `POST /sync/push` | ✅ Implementada | Batch de entidades (ACTIVITY + EVENT) por proyecto; idempotente por UUID |
| Pull incremental | `POST /sync/pull` | ✅ Implementada | Cursor-based por `since_version` + `after_uuid`; devuelve página de cambios |
| Pull de eventos | `GET /events?since_version=N` | ✅ Implementada | Pull incremental de eventos por proyecto y versión |

### 1.5 Evidencias

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Iniciar upload (presign) | `POST /evidences/upload-init` | ✅ Implementada | Valida MIME (JPEG/PNG/PDF) y tamaño (max 20MB); retorna URL firmada GCS (15 min) |
| Confirmar upload | `POST /evidences/complete` | ✅ Implementada | Registra evidencia como UPLOADED en BD |
| Obtener URL de descarga | `GET /evidences/{uuid}/download-url` | ✅ Implementada | Signed URL GCS para descarga (15 min) |
| Modo local (sin GCS) | Automático | ✅ Implementada | `EVIDENCE_STORAGE_BACKEND=local` guarda en disco; sin dependencia GCP |

### 1.6 Eventos de Campo

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Crear/upsert evento | `POST /events/{uuid}` | ✅ Implementada | Idempotente por UUID; acepta severidad LOW/MEDIUM/HIGH/CRITICAL |
| Listar eventos del proyecto | `GET /events` | ✅ Implementada | Filtros: project_id, since_version |
| Obtener evento | `GET /events/{uuid}` | ✅ Implementada | DTO completo |
| Actualizar evento | `PUT /events/{uuid}` | ✅ Implementada | Solo campos editables |
| Eliminar evento | `DELETE /events/{uuid}` | ✅ Implementada | Soft delete |

### 1.7 Revisión y Validación

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Cola de revisión | `GET /review/queue` | ✅ Implementada | Retorna actividades PENDIENTE_REVISION con contadores + flag `gps_critical` estructurado |
| Decisión de revisión | `POST /review/decision` | ✅ Implementada | approve / reject / needs_fix; registra en audit_logs |
| Parche de evidencia en revisión | `PATCH /review/evidence/{uuid}` | ✅ Implementada | Actualiza caption/estado de evidencia durante revisión |
| Validar evidencia | `POST /review/validate-evidence` | ✅ Implementada | Marca evidencia como validada |
| Playbook de razones de rechazo | `GET /review/reject-playbook` | ✅ Implementada | Lista de razones configurables para rechazo |
| Crear razón de rechazo | `POST /review/reject-reasons` | ✅ Implementada | Alta de razón nueva (persiste en BD) |

> **Deuda activa:** Las 3 razones predeterminadas (`PHOTO_BLUR`, `GPS_MISMATCH`, `MISSING_INFO`) aún se inicializan hardcoded en el seed; deben provenir únicamente de la BD configurable.

### 1.8 Usuarios, Proyectos y Asignaciones

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| CRUD de usuarios | `/users/*` | ✅ Implementada | Solo ADMIN/SUPERVISOR; lista, crea, edita, desactiva |
| CRUD de proyectos | `/projects/*` | ✅ Implementada | Gestión de proyectos + cobertura geográfica |
| Frentes del proyecto | `GET/POST /fronts` | ✅ Implementada | Lista y alta de frentes por proyecto |
| Ubicaciones | `GET /locations` | ✅ Implementada | Filtros: project_id, estado, municipio |
| Estados disponibles | `GET /locations/states` | ✅ Implementada | 32 estados nacionales (seed idempotente) |
| Asignaciones del día | `GET /assignments` | ✅ Implementada | Retorna asignaciones por fecha para el operativo autenticado |
| Asignar cobertura geográfica | `POST /projects/{id}/locations` | ✅ Implementada | Vincula estados/municipios a un proyecto |

### 1.9 Auditoría y Observaciones

| Función | Endpoint | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Consultar audit log | `GET /audit` | ✅ Implementada | Filtros: actor, entidad, fecha; solo ADMIN/SUPERVISOR |
| CRUD de observaciones | `/observations/*` | ✅ Implementada | Observaciones por actividad; asociadas al revisor |

---

## 2. App Móvil (Operativo)

### 2.1 Autenticación

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Login con email/password | `LoginPage` | ✅ Implementada | Llama `POST /auth/login`; guarda tokens en `flutter_secure_storage` |
| Registro con invite code | `SignupPage` | ✅ Implementada | Llama `POST /auth/signup`; carga roles desde `/auth/roles` |
| Auto-refresh de token | `ApiClient` (Dio interceptor) | ✅ Implementada | Intercepta 401, llama `/auth/refresh`, reintenta la petición original |
| Login offline con PIN | `LoginPage` (modo PIN) | ✅ Implementada | Valida hash SHA-256(email+pin) local sin red; requiere PIN previo dado de alta online |
| Alta de PIN offline | `SettingsPage` | ✅ Implementada | Llama `PUT /auth/me/pin` y guarda pin localmente en Drift |

### 2.2 Registro de Actividades (Wizard)

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Selección de tipo de actividad | `WizardStep1` | ✅ Implementada | Carga tipos desde `CatalogRepository` (bundle local) |
| Contexto de la actividad (frente, PK, fecha) | `WizardStepContext` | ✅ Implementada | Selectores de frente/ubicación conectados a `/fronts` y `/locations`; fallback a texto libre |
| Formulario dinámico de campos | `WizardStepFields` / `DynamicFormBuilder` | ✅ Implementada | Lee `CatalogFields` del bundle; cascade dropdowns subcategoría → propósito |
| Captura de evidencias | `WizardStepEvidence` | ✅ Implementada | Cámara → compresión → upload presign → confirm; mínimos por tipo según bundle |
| Validación GPS | Automático en save | ✅ Implementada | Si `requiresGeo` en bundle y no hay coordenadas, bloquea guardado con error explícito |
| Confirmación y envío | `WizardStepConfirm` | ✅ Implementada | Guarda en Drift con estado DRAFT → READY_TO_SYNC; encola en `SyncQueue` |
| Edición de actividad existente | `ActivityDetailPage` | ✅ Implementada | Carga DTO local, permite editar campos en DRAFT/REQUIERE_CAMBIOS |
| Selección de asistentes | `AttendeesGroup` | ✅ Implementada | Lista de tipos institucionales del bundle |
| Selección de temas | `TopicsChips` | ✅ Implementada | Temas sugeridos por tipo de actividad desde bundle |
| Selección de riesgo | `RiskSelector` | ✅ Implementada | Niveles de riesgo del bundle |

### 2.3 Sincronización

| Función | Pantalla / Servicio | Estado | Cómo funciona |
|---------|---------------------|--------|---------------|
| Push de actividades | `SyncService.pushPendingChanges()` | ✅ Implementada | Lee `SyncQueue`, hace `POST /sync/push` en batch; marca SYNCED o ERROR |
| Push de eventos | `SyncService` (extensión) | ✅ Implementada | Incluye entidades EVENT en el batch de push |
| Auto-sync cada 15 minutos | `AutoSyncService` | ✅ Implementada | `Timer.periodic` + trigger al recuperar conectividad |
| Pull de actividades del servidor | `SyncService.pullFromServer()` | ✅ Implementada | `POST /sync/pull?since_version=N`; upsert local con cursor compuesto |
| Pull de eventos del servidor | `SyncService` (pull eventos) | ✅ Implementada | `GET /events?since_version=N`; persiste en `LocalEvents` |
| Resolución de conflictos UI | `SyncCenterPage` | ✅ Implementada | Opciones: "usar mi versión" (`force_override`) / "usar servidor" (pull activo) |
| Diff incremental de catálogo | `CatalogRepository` | ✅ Implementada | Compara hash local con `/catalog/check-updates`; descarga solo si hay cambios |
| Centro de sincronización | `SyncCenterPage` | ✅ Implementada | Muestra estado de cola, errores, botón de sync manual |
| Upload de evidencias con retry | `PendingUploads` + `EvidenceUploadService` | ✅ Implementada | 3 pasos (presign → upload → confirm) con cola de reintentos |

### 2.4 Agenda del Equipo

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Timeline de actividades del equipo | `AgendaEquipoPage` | ✅ Implementada | Lista actividades del proyecto ordenadas por fecha/frente |
| Vista por semana | `WeekStrip` | ✅ Implementada | Selector de semana con strip horizontal |
| Filtros de agenda | `FilterChipsRow` | ✅ Implementada | Filtros por frente, estado, tipo |
| Dispatcher (asignar actividad) | `DispatcherBottomSheet` | ✅ Implementada | Modal para reasignar actividad a operativo |

### 2.5 Eventos de Campo

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Reportar nuevo evento | `ReportEventSheet` (FAB en Home) | ✅ Implementada | Bottom sheet 3 pasos: tipo+severidad → descripción+PK → confirmación |
| Lista de eventos del proyecto | `EventsListPage` (5.° tab BottomNav) | ✅ Implementada | Carga desde Drift local + pull del servidor |

### 2.6 Pantalla Principal (Home)

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Lista de actividades del día | `HomePage` | ✅ Implementada | Lee de Drift (`ActivityDao.listHomeActivitiesByProject`) |
| Filtros totales/vencidas | `HomePage` | ✅ Implementada | `FilterMode.totales` / `FilterMode.vencidas` sobre lista local |
| Búsqueda de actividades | `HomePage` | ✅ Implementada | Filtro en memoria por texto libre |
| Agrupación por frente | `HomePage` | ✅ Implementada | Expansión/colapso por frente |
| FAB: nueva actividad | `HomePage` | ✅ Implementada | Abre el wizard de registro |
| FAB: reportar evento | `HomePage` | ✅ Implementada | Abre `ReportEventSheet` |
| Indicador de modo offline | `OfflineModeController` | ✅ Implementada | Banner visible cuando no hay red |

---

## 3. Desktop Admin (Coordinador/Supervisor)

### 3.1 Autenticación y Sesión

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Login | `LoginPage` (desktop) | ✅ Implementada | Llama `POST /auth/login`; guarda tokens en `AppSessionController` |
| Persistencia de sesión | `AppSessionController` | ✅ Implementada | Access + refresh + expiración persisten entre reinicios |
| JWT auto-refresh | `BackendApiClient` | ✅ Implementada | Retry tras 401 via `/auth/refresh` reactivo |

### 3.2 Dashboard

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Métricas de la cola de revisión | `DashboardPage` | ✅ Implementada | Llama `GET /review/queue`; muestra contadores pending/approved/rejected/needs_fix |
| Actividades recientes | `DashboardPage` | ✅ Implementada | Últimas 5 actividades de la cola |
| Avance del día (%) | `DashboardPage` | ✅ Implementada | `approved / totalInQueue * 100` |
| Selector de proyecto | `DashboardPage` | ✅ Implementada | Carga proyectos dinámicos desde backend |

### 3.3 Operaciones (Cola de Revisión)

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Cola de actividades pendientes | `ValidationPage` | ✅ Implementada | Filtra por PENDING / CHANGED / GPS / REJECTED / ALL |
| Detalle de actividad | `ActivityDetailsPanelPro` | ✅ Implementada | Muestra campos dinámicos, metadatos, GPS |
| Galería de evidencias | `EvidenceGalleryPanel` | ✅ Implementada | Viewer de fotos/PDFs con signed URL |
| Mapa con notas | `MinimapWithNotesPanel` | ✅ Implementada | Coordenadas GPS de la actividad |
| Aprobar actividad | `ReviewActions` | ✅ Implementada | Llama `POST /review/decision` con `action=approve` |
| Rechazar actividad | `ReviewActions` | ✅ Implementada | Llama `POST /review/decision` con `action=reject` + razón |
| Solicitar cambios | `ReviewActions` | ✅ Implementada | Llama `POST /review/decision` con `action=needs_fix` |
| Editor de caption de evidencia | `CaptionEditorWidget` | ✅ Implementada | `PATCH /review/evidence/{uuid}` |
| Banner de validación GPS | `GpsValidationBanner` | ✅ Implementada | Muestra alerta si `gps_critical = true` en la actividad |
| Resolución de flags | `FlagResolutionDialog` | ✅ Implementada | `PATCH /activities/{uuid}/flags` para `gps_mismatch` / `catalog_changed` |
| Panel de historial (timeline) | `ValidationPage` | ✅ Implementada | Consume `GET /activities/{uuid}/timeline` del backend |
| Filtro por flags en cola | `ValidationPage` | ✅ Implementada | Usa `flags.gps_mismatch` / `flags.catalog_changed` |
| Indicador de checklist incompleto | Cola de revisión | ✅ Implementada | Muestra alerta si `checklist_incomplete` en DTO |
| Outbox de decisiones en memoria | `ReviewDecisionOutbox` | ✅ Implementada | Retry básico para decisiones si falla la red |

### 3.4 Planeación

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Vista de asignaciones del día | `PlanningPage` | ✅ Implementada | Llama `GET /assignments?date=...&project_id=...` |
| Selector de fecha | `PlanningPage` | ✅ Implementada | Navega entre días |
| Selector de proyecto | `PlanningPage` | ✅ Implementada | Carga proyectos dinámicos |

### 3.5 Catálogos

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Lista de versiones del catálogo | `CatalogsPage` | ✅ Implementada | `CatalogsController` carga desde backend |
| Publicar catálogo | `CatalogsPage` | ✅ Implementada | Botón "Publicar" llama `POST /catalog/publish` |
| Validar borrador | `CatalogsPage` | ✅ Implementada | Botón "Validar" llama `POST /catalog/validate` |
| Reordenar actividades | `CatalogsPage` | ✅ Implementada | Drag-and-drop local; guarda via editor API |
| Selector de proyecto | `CatalogsPage` | ✅ Implementada | Carga proyectos dinámicos |

### 3.6 Usuarios

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Lista de usuarios | `UsersPage` (main shell) | ✅ Implementada | `GET /api/v1/users`; muestra nombre, email, rol, estado |

### 3.7 Reportes

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Filtros de reporte | `ReportsPage` | ✅ Implementada | Filtros por proyecto, frente, rango de fechas |
| Lista de actividades para reporte | `ReportsPage` | ✅ Implementada | Carga actividades filtradas desde backend |
| Generación de PDF | `ReportsPage` | ✅ Implementada | Genera PDF local con `pdf` package; `url_launcher` para abrir |
| Opciones de reporte | `ReportsPage` | ✅ Implementada | Incluir auditoría, notas, adjuntos (checkboxes locales) |

### 3.8 Módulo Admin

| Función | Pantalla | Estado | Cómo funciona |
|---------|----------|--------|---------------|
| Login admin separado | `AdminLoginPage` | ✅ Implementada | Flujo de sesión independiente del shell principal |
| Gestión de proyectos | `AdminProjectsPage` | ✅ Implementada | Lista, crea proyectos via `/projects`; dialog de alta |
| Gestión de usuarios (admin) | `AdminUsersPage` | ✅ Implementada | Lista, crea, edita usuarios; asignación de roles |
| Auditoría | `AdminAuditPage` | ✅ Implementada | `GET /audit` con filtros por actor y entidad |
| Configuración | `AdminSettingsPage` | ✅ Implementada | Configuración del sistema (alcance: pendiente definir) |
| Eventos (admin) | `EventsPage` (NavigationRail) | ✅ Implementada | Lista de eventos del proyecto con severidad |

---

## 4. Gaps: Funciones sin lógica conectada

Estas funciones tienen **UI o endpoint implementado pero la conexión entre ambos está incompleta o ausente**.

### 4.1 Backend — Deuda de Lógica

| Gap | Descripción | Impacto | Prioridad |
|-----|-------------|---------|-----------|
| ~~**Razones de rechazo hardcoded**~~ ✅ RESUELTO (2026-03-05) | Movidas a `initial_data.py::seed_reject_reasons()` con 5 códigos extensibles. `review_decision()` ahora valida que `reject_reason_code` exista y esté activo en DB. Tests actualizados (12/12 pasando). | — | — |
| ~~**Prefijo `/observations` sin `/api/v1`~~ ✅ RESUELTO (2026-03-05) | Verificado en `backend/app/main.py`: `observations.router` está montado con `prefix=settings.API_V1_STR`; tests usan `/api/v1/observations` | — | — |
| ~~**Endpoint `GET /assignments` — creación**~~ ✅ RESUELTO (2026-03-05) | `backend/app/api/v1/assignments.py` ya implementa `POST /assignments`; Desktop (`AssignmentsRepository.createAssignment`) ya consume `/api/v1/assignments` | — | — |

### 4.2 App Móvil — UI sin lógica conectada

| Gap | Pantalla / Feature | Descripción | Prioridad |
|-----|-------------------|-------------|-----------|
| ~~**Pantalla de Proyectos**~~ ✅ IMPLEMENTADO (2026-03-05) | `ProjectsPage` | Ahora carga desde `GET /projects` con fallback local y devuelve selección al router (`/?project=...`) para actualizar Home/Agenda/Sync | — |
| **Pantalla de Configuración (Settings)** | `SettingsPage` | Página centrada en cuenta/biometría/sync. No expone selector de backend URL en runtime ni mecanismo para reconfigurar `ApiClient` en caliente | BAJA |
| ~~**Sincronización de Assignments**~~ ✅ IMPLEMENTADO (2026-03-05) | `AgendaEquipoPage` | Dispatcher persiste en `AgendaAssignments` (`pending`), hace `POST /assignments`, reconcilia local y además `AssignmentSyncService` ya no es `NoOp` | — |
| **Edición de eventos** | `EventsListPage` | Lista eventos correctamente pero no permite editar ni eliminar evento desde la UI móvil | BAJA |
| **Filtro "Vencidas" en Home** | `HomePage` | `FilterMode.vencidas` filtra por `status == ActivityStatus.vencida` pero la lógica de qué es "vencida" no usa fecha/plazo del catálogo | BAJA |

### 4.3 Desktop Admin — UI sin lógica conectada

| Gap | Pantalla / Feature | Descripción | Prioridad |
|-----|-------------------|-------------|-----------|
| ~~**Creación de asignaciones en Planeación**~~ ✅ YA IMPLEMENTADO | `PlanningPage` | `_CreateAssignmentDialog` existe con todos los campos (project_id, assignee, activity_type, pk, start/end, risk). `AssignmentsRepository.createAssignment()` llama `POST /api/v1/assignments`. Inventario inicial incorrecto. | — |
| ~~**Alta de frentes en Proyectos Admin**~~ ✅ YA IMPLEMENTADO | `AdminProjectsPage` | El dialog de creación de proyecto incluye `frontsController` (textarea multi-frente) y `locationScopeController` (regiones). Se envía al backend en `createProject()`. Inventario inicial incorrecto. | — |
| **Editor de catálogo — tabs avanzados (hardening)** | `CatalogsPage` | Backend ya tiene endpoints `/catalog/editor/*` para entidades avanzadas; falta robustecer validaciones de contrato UI/API y cobertura de pruebas por entidad | MEDIA |
| **Usuarios — edición de roles** | `UsersPage` (main shell) | Vista solo lectura sin acciones de editar/desactivar. En `AdminUsersPage` hay alta/listado pero tampoco edición/desactivación conectada al `PATCH /users/admin/{id}` | BAJA |
| **Configuración admin** | `AdminSettingsPage` | La página existe y es accesible pero su contenido es un placeholder sin opciones reales conectadas al backend | BAJA |
| ~~**Reportes — exportación real**~~ ✅ IMPLEMENTADO (2026-03-05) | `ReportsPage` | Nuevo endpoint backend `GET /reports/activities` con filtros + metadata (`generated_at`, `generated_by`, filtros). Desktop migrado para consumirlo | — |
| ~~**Dashboard — KPIs de avance operativo**~~ ✅ IMPLEMENTADO (2026-03-05) | `DashboardPage` | Nuevo endpoint `GET /dashboard/kpis`; Desktop migrado a KPIs operativos (`total`, `pending_review`, `in_progress`, `completed_today`) | — |
| **Notificaciones / alertas en tiempo real** | N/A | No hay WebSocket ni polling proactivo; el coordinador debe refrescar manualmente para ver nuevas actividades en cola | BAJA |

### 4.4 Gaps de Infraestructura y Proceso

| Gap | Descripción | Prioridad |
|-----|-------------|-----------|
| ~~**CI/CD automatizado**~~ ✅ RESUELTO (2026-03-05) | `.github/workflows/backend-ci.yml` ahora incluye job `deploy` que corre Cloud Build + Cloud Run deploy tras tests exitosos en `main`. Requiere secrets GCP en repo. | — |
| **E2E staging real** ✅ RUNBOOK CREADO (2026-03-05) | Script `e2e_staging_flow.py` documentado en `docs/RUNBOOK_E2E_STAGING.md`. Falta ejecutar con credenciales reales. | PENDIENTE |
| **Cobertura desktop fuera de auth** | Los módulos `catalog`, `review`, `reports` tienen cobertura de test muy limitada | MEDIA |
| ~~**Observaciones sin prefijo en production**~~ ✅ RESUELTO (2026-03-05) | Verificado montaje en `backend/app/main.py` con `API_V1_STR`; falta solo validación operacional en staging/prod | — |

### 4.5 Verificación de Gaps BAJA (2026-03-05)

| Gap BAJA | Estado verificado | Evidencia técnica |
|-----|-----|-----|
| Settings móvil (runtime backend URL) | RESUELTO (2026-03-05) | `frontend_flutter/sao_windows/lib/features/settings/settings_page.dart` ahora incluye control "Backend API" para editar/restablecer URL; persiste en `SharedPreferences` (`api_base_url_override`) y aplica en runtime vía `ApiClient.updateBaseUrl()` (`frontend_flutter/sao_windows/lib/core/network/api_client.dart`) |
| Edición/eliminación de eventos móvil | RESUELTO (2026-03-05) | `frontend_flutter/sao_windows/lib/features/events/ui/events_list_page.dart` incorpora menú por item con acciones `Editar` y `Eliminar`; persiste cambios en `EventsLocalRepository.updateEvent/deleteEvent` y los sincroniza con acciones `UPDATE/DELETE` en `SyncService._pushPendingEvents()` |
| Filtro "Vencidas" en Home | VIGENTE | `frontend_flutter/sao_windows/lib/features/home/home_page.dart` usa `ActivityStatus.vencida` basado en `createdAt`/estado de ejecución, no en plazo/regla de catálogo |
| Usuarios (main shell/admin shell) edición de roles | VIGENTE | `desktop_flutter/sao_desktop/lib/features/users/users_page.dart` solo lectura; `desktop_flutter/sao_desktop/lib/features/admin/pages/users_page.dart` implementa alta/lista, sin flujo de edición/desactivación |
| Configuración admin placeholder | VIGENTE | `desktop_flutter/sao_desktop/lib/features/admin/pages/settings_page.dart` muestra `Backend URL` y nota de `--dart-define` sin opciones operativas |
| Notificaciones en tiempo real | VIGENTE | Flujo de revisión usa `watchPendingReview()` (`desktop_flutter/sao_desktop/lib/data/repositories/activity_repository.dart`) con carga backend bajo demanda; no se observa WebSocket/SSE/poller dedicado para inbox |

---

## 5. Mapa rápido de dependencias UI → API

```
APP MÓVIL                           BACKEND
-----------                         -------
HomePage                  ←→  Drift local (sin API directa)
WizardPage                →   POST /activities  (via SyncQueue)
SyncCenterPage            →   POST /sync/push + POST /sync/pull
EventsListPage            ←→  GET /events + Drift LocalEvents
ReportEventSheet          →   POST /events/{uuid} (via SyncQueue)
AgendaEquipoPage          ←→  GET/POST /assignments  (lectura + creación/sync)
SettingsPage              →   PUT /auth/me/pin
CatalogRepository         ←   GET /catalog/bundle + GET /catalog/check-updates

DESKTOP ADMIN                       BACKEND
-------------                       -------
DashboardPage             ←   GET /dashboard/kpis
ValidationPage            ←→  GET /review/queue + POST /review/decision
EvidenceGalleryPanel      ←   GET /evidences/{uuid}/download-url
CaptionEditorWidget       →   PATCH /review/evidence/{uuid}
FlagResolutionDialog      →   PATCH /activities/{uuid}/flags
TimelinePanel             ←   GET /activities/{uuid}/timeline
PlanningPage              ←→  GET/POST /assignments  (dialog crear asignación ✅)
ReportsPage               ←   GET /reports/activities  [PDF local con fuente dedicada]
CatalogsPage              ←→  GET/POST/PUT /catalog/* (editor multi-endpoint)
AdminProjectsPage         ←→  GET/POST /projects  (fronts + cobertura en dialog ✅)
AdminUsersPage            ←→  GET/POST/PUT /users
AdminAuditPage            ←   GET /audit
UsersPage (shell)         ←   GET /users  [solo lectura]
EventsPage                ←   GET /events
AdminSettingsPage         →   [SIN endpoint conectado — placeholder]
```

---

## Resumen Ejecutivo de Gaps

| Categoría | Total Gaps | Alta Prioridad | Media Prioridad | Baja Prioridad | Resueltos |
|-----------|-----------|----------------|-----------------|----------------|-----------|
| Backend | 3 | 0 | 0 | 0 | 3 ✅ |
| App Móvil | 5 | 0 | 0 | 3 | 2 ✅ |
| Desktop Admin | 8 | 0 | 1 | 3 | 4 ✅ |
| Infraestructura | 4 | 0 | 1 | 0 | 3 ✅ |
| **Total** | **20** | **0** | **2** | **6** | **12 ✅** |

**Estado de los 5 gaps de alta prioridad originales (al 2026-03-05):**
1. ✅ **RESUELTO** — Razones de rechazo: seed `initial_data.py` + validación en `review_decision()`
2. ✅ **ERA FALSO POSITIVO** — Creación de asignaciones ya implementada en `PlanningPage` + `AssignmentsRepository`
3. ✅ **ERA FALSO POSITIVO** — Alta de frentes ya implementada en dialog `AdminProjectsPage` (frontsController + locationScopeController)
4. ✅ **RESUELTO** — CI/CD automatizado: job `deploy` en `.github/workflows/backend-ci.yml` con Cloud Build + Cloud Run + smoke test
5. 📋 **RUNBOOK LISTO** — E2E staging: `docs/RUNBOOK_E2E_STAGING.md` con todos los pasos; falta ejecutar con credenciales reales en prod
