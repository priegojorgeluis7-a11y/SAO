# REPO_MAP.md — Mapa Exacto del Repositorio SAO

> Fuente de verdad sobre qué archivo contiene qué.
> Usar junto con [AGENT_CONTEXT.md](AGENT_CONTEXT.md).
> Última actualización: 2026-02-25

---

## ⚠️ Discrepancias Críticas (leer antes de tocar sync)

### 1. ExecutionState existe en 3 formas distintas

| Capa | Archivo | Línea | Valores |
|------|---------|-------|---------|
| **Backend** | `backend/app/models/activity.py` | 10 | `PENDIENTE, EN_CURSO, REVISION_PENDIENTE, COMPLETADA` |
| **Mobile UI** | `frontend_flutter/sao_windows/lib/features/home/models/today_activity.dart` | 7 | `pendiente, enCurso, revisionPendiente, terminada` |
| **Sync DTO** | `frontend_flutter/sao_windows/lib/features/sync/models/sync_dto.dart` | 57 | `String` raw (sin enum, pasa directo al JSON) |

**⚠️ `terminada` (Dart) ≠ `COMPLETADA` (backend).** Al implementar sync push, el mapper debe convertir `ExecutionState.terminada` → `"COMPLETADA"` antes de serializar.

### 2. Activities Drift ≠ ActivityDTO — campos con nombres distintos

| Campo en `ActivityDTO` (sync) | Campo en `Activities` (Drift/local) | Notas |
|---|---|---|
| `pkStart` / `pkEnd` (rango) | `pk` (un solo int) | Drift solo guarda un PK, el DTO tiene rango |
| `execution_state` (workflow) | `status` (pipeline) | Son **máquinas de estado distintas** — ver abajo |
| `uuid` + `serverId` | `id` (uuid) + `serverRevision` | Naming diferente |
| `frontId` | `segmentId` | Mismo concepto, nombre distinto |
| `catalogVersionId` | `activityTypeId` → FK a `CatalogActivityTypes` | Granularidad diferente |

**Las dos máquinas de estado son intencionales:**
- `ExecutionState` (UI): estado operativo visible al usuario (pendiente/enCurso/revisionPendiente/terminada)
- `Activities.status` (Drift sync pipeline): fase de persistencia (DRAFT → READY_TO_SYNC → SYNCED → ERROR)

---

## Backend — Python (`backend/app/`)

### Entrypoint y Core

| Archivo | Responsabilidad |
|---------|----------------|
| `main.py` | FastAPI app factory, registra routers, CORS |
| `core/config.py` | `Settings` pydantic-settings: `DATABASE_URL`, `SECRET_KEY`, `GCS_BUCKET`, `GCS_CREDENTIALS` |
| `core/database.py` | SQLAlchemy engine + `SessionLocal` + `get_db` dependency |
| `core/security.py` | `create_access_token()`, `verify_password()`, `get_password_hash()` |
| `api/deps.py` | `get_current_user` (dependency inyectada en todos los routers protegidos) |

### Endpoints (`api/v1/`)

| Archivo | Endpoints | Método + Ruta |
|---------|-----------|---------------|
| `auth.py` | 3 | `POST /auth/login` · `POST /auth/refresh` · `GET /auth/me` |
| `activities.py` | 5 | `POST /activities` · `GET /activities` · `GET /activities/{uuid}` · `PUT /activities/{uuid}` · `DELETE /activities/{uuid}` |
| `catalog.py` | 8 | `GET /catalog/latest` · `GET /catalog/check-updates` · `GET /catalog/versions` · `GET /catalog/versions/{id}` · `POST /catalog/versions/{id}/publish` · `GET /catalog/effective` · `GET /catalog/current-version` · `GET /catalog/diff` |
| `sync.py` | 2 | `POST /sync/pull` · `POST /sync/push` |
| `evidences.py` | 3 | `POST /evidences/init-upload` · `POST /evidences/complete-upload` · `GET /evidences/{id}/download-url` |

### Modelos SQLAlchemy (`models/`)

| Archivo | Clases | Notas |
|---------|--------|-------|
| `base.py` | `BaseModel` | `id`, `created_at`, `updated_at` (heredado por todos) |
| `user.py` | `User`, `UserStatus` | `UserStatus`: active/inactive/locked |
| `role.py` | `Role` | 5 roles: ADMIN, COORD, SUPERVISOR, OPERATIVO, LECTOR |
| `permission.py` | `Permission`, `RolePermission` | resource.action (activity.create, etc.) |
| `user_role_scope.py` | `UserRoleScope` | RBAC multi-tenant: user→role→(project?, front?) |
| `project.py` | `Project` | id=VARCHAR ('TMQ', 'TAP') |
| `front.py` | `Front` | Frente/segmento con pk_start/pk_end |
| `location.py` | `Location` | estado + municipio |
| `activity.py` | `Activity`, `ExecutionState` | **ExecutionState en línea 10**; `uuid` UNIQUE INDEX |
| `evidence.py` | `Evidence` | GCS key + signed URL logic |
| `catalog.py` | `CatalogVersion`, `CatActivityType`, `CatEventType`, `CatFormField`, `CatWorkflowState`, `CatWorkflowTransition`, `CatEvidenceRule`, `CatChecklistTemplate` | 7 entidades catalog + version |
| `catalog_effective.py` | `EffectiveCatalog`-related + `ProjCatalogOverride` | Override por proyecto |

### Schemas Pydantic (`schemas/`)

| Archivo | Clases |
|---------|--------|
| `activity.py` | `ActivityBase`, `ActivityCreate`, `ActivityUpdate`, `ActivityDTO`, `ActivityListResponse`, `ActivitySyncPushRequest`, `ActivitySyncPushResponse`, `ActivitySyncPullResponse` |
| `auth.py` | `LoginRequest`, `TokenResponse`, `RefreshRequest`, `UserMe` |
| `catalog.py` | `CatalogPackage` + entidades CAT_* |
| `sync.py` | `SyncPullRequest`, `SyncPullResponse`, `SyncPushRequest`, `SyncPushResponse` |
| `evidence.py` | `EvidenceInitRequest`, `EvidenceCompleteRequest`, `EvidenceDownloadResponse` |
| `user.py` | `UserCreate`, `UserUpdate`, `UserResponse` |
| `effective_catalog.py` | Schemas para catalog effective + diff |

### Servicios (`services/`)

| Archivo | Clase | Métodos clave |
|---------|-------|---------------|
| `activity_service.py` | `ActivityService` | `create()`, `get_by_uuid()`, `update()`, `soft_delete()`, sync helpers |
| `catalog_service.py` | `CatalogService` | `get_latest_published()`, `check_updates()`, `publish_version()`, `catalog_hash()` |
| `effective_catalog_service.py` | `EffectiveCatalogService` | `get_effective_catalog()`, `diff_effective_catalog()` |
| `evidence_service.py` | `EvidenceService` | `generate_upload_url()`, `complete_upload()`, `generate_download_url()` (GCS) |

### Seeds (`seeds/`)

| Archivo | Contenido | Tamaño |
|---------|-----------|--------|
| `initial_data.py` | 5 roles, 12 permisos, role-permission map, `admin@sao.com`, proyecto TMQ con 3 frentes | 200 LOC |
| `catalog_tmq_v1.py` | CatalogVersion 1.0.0 PUBLISHED: 5 ActivityTypes, 4 EventTypes, 20+ FormFields, 4 WorkflowStates, 8 Transitions, 3 EvidenceRules, 2 ChecklistTemplates | 596 LOC |

### Tests (`tests/`)

| Archivo | Qué prueba | Tests |
|---------|-----------|-------|
| `conftest.py` | Fixtures: `db_session`, `test_client`, `auth_headers` | — |
| `test_auth.py` | login, refresh, me endpoint | ~4 |
| `test_security.py` | password hash, JWT encode/decode | ~4 |
| `test_activities.py` | CRUD activities | ~3 |
| `test_catalog_effective.py` | catalog versioning + effective | ~4 |
| `test_evidences.py` | GCS signed URLs | ~4 |
| `test_sync.py` | push/pull sync | ~14 |

---

## App Móvil — Dart (`frontend_flutter/sao_windows/lib/`)

### Core — Infraestructura Transversal

| Archivo | Responsabilidad |
|---------|----------------|
| `core/di/service_locator.dart` | GetIt: registra `ApiClient`, `TokenStorage`, todos los repositorios |
| `core/network/api_client.dart` | Dio + interceptor JWT auto-refresh (401 → refresh → retry) |
| `core/network/api_config.dart` | `baseUrl`, timeouts (connect/receive/send) |
| `core/network/exceptions.dart` | `AuthExpiredException`, `TokenRefreshException`, `NetworkException` |
| `core/network/network.dart` | barrel de network |
| `core/auth/auth.dart` | barrel de auth |
| `core/auth/token_storage.dart` | `flutter_secure_storage`: `saveTokens()`, `getAccessToken()`, `isExpired()` |
| `core/routing/app_router.dart` | `go_router` con guards de auth |
| `core/routing/app_routes.dart` | Constantes de rutas (`AppRoutes.home`, etc.) |
| `core/config/app_config.dart` | `AppConfig.baseUrl` (env-aware) |
| `core/config/data_mode.dart` | `enum DataMode { live, mock, offline }` |
| `core/services/connectivity_service.dart` | Check de red antes de sync |
| `core/services/biometric_service.dart` | `flutter_local_auth` (pendiente integración) |
| `core/storage/kv_store.dart` | Key-value store (SharedPreferences wrapper) |
| `core/utils/logger.dart` | Logger utility con niveles |
| `core/utils/uuid.dart` | `generateUuid()` para business keys |

### Data Layer — Drift (SQLite local)

**Fuente de verdad del schema:** `data/local/tables.dart`

| Tabla Drift | Campos clave | Estado string |
|-------------|-------------|---------------|
| `Roles` | `id`, `name`, `permissionsJson` | — |
| `Users` | `id` (uuid), `name`, `roleId`, `isActive` | — |
| `Projects` | `id`, `code` (TMQ), `name`, `isActive` | — |
| `ProjectSegments` | `id`, `projectId`, `pkStart`, `pkEnd` | — |
| `CatalogVersions` | `id`, `projectId`, `versionNumber`, `publishedAt`, `checksum` | — |
| `CatalogActivityTypes` | `id`, `code`, `requiresPk`, `requiresGeo`, `requiresEvidence` | — |
| `CatalogFields` | `id`, `activityTypeId`, `fieldKey`, `fieldType`, `optionsJson`, `requiredField` | `fieldType`: text\|number\|date\|select\|… |
| `CatActivities` | `id`, `name`, `versionId` | — |
| `CatSubcategories` | `id`, `activityId`, `name` | — |
| `CatPurposes` | `id`, `activityId`, `subcategoryId`, `name` | — |
| `CatTopics` | `id`, `type`, `name` | — |
| `CatRelActivityTopics` | `activityId`, `topicId` | — |
| `CatResults` | `id`, `name`, `category`, `severity` | — |
| `CatAttendees` | `id`, `type`, `name` | — |
| `Activities` | `id` (uuid), `projectId`, `segmentId`, `activityTypeId`, `pk`, `createdByUserId`, `localRevision`, `serverRevision` | `status`: DRAFT\|READY_TO_SYNC\|SYNCED\|ERROR\|CANCELED |
| `ActivityFields` | `id`, `activityId`, `fieldKey`, `valueText`, `valueNumber`, `valueDate`, `valueJson` | EAV pattern |
| `ActivityLog` | `id`, `activityId`, `eventType`, `at`, `userId` | `eventType`: CREATED\|EDITED\|SUBMITTED\|SYNC_OK\|SYNC_FAIL |
| `Evidences` | `id`, `activityId`, `type`, `filePathLocal`, `fileHash`, `geoLat`, `geoLon` | `status`: LOCAL_ONLY\|QUEUED\|UPLOADED\|ERROR |
| `PendingUploads` | `id`, `activityId`, `localPath`, `evidenceId`, `signedUrl`, `attempts`, `nextRetryAt` | `status`: PENDING_INIT\|PENDING_UPLOAD\|PENDING_COMPLETE\|DONE\|ERROR |
| `SyncQueue` | `id`, `entity`, `entityId`, `action`, `payloadJson`, `priority`, `attempts` | `status`: PENDING\|IN_PROGRESS\|DONE\|ERROR; `action`: UPSERT\|DELETE; `entity`: ACTIVITY\|EVIDENCE\|CATALOG |
| `SyncState` | `id=1`, `lastSyncAt`, `lastServerCursor`, `lastCatalogVersionByProjectJson` | singleton |

**DAOs:**
- `dao/activity_dao.dart` — queries sobre `Activities` + `ActivityFields`
- `dao/catalog_dao.dart` — queries sobre todas las tablas `Cat*`
- `dao/projects_dao.dart` — queries sobre `Projects` + `ProjectSegments`
- `db_instance.dart` — singleton `AppDatabase` (GetIt-registered)
- `app_db.dart` — `@DriftDatabase(tables: [...])` registro completo
- `app_db.g.dart` — **NO EDITAR** (generado por build_runner)

### Features

#### Auth
| Archivo | Clase / Función |
|---------|----------------|
| `features/auth/data/auth_repository.dart` | `AuthRepository.login()`, `.logout()`, `.refreshSession()` |
| `features/auth/data/auth_provider.dart` | `AuthState`, `AuthNotifier` (StateNotifier Riverpod) |
| `features/auth/data/models/login_request.dart` | `LoginRequest` |
| `features/auth/data/models/token_response.dart` | `TokenResponse` |
| `features/auth/data/models/user.dart` | `User` (local model) |
| `features/auth/application/auth_providers.dart` | `authProvider`, `authControllerProvider`, `requireAuthProvider` |
| `features/auth/presentation/login_page.dart` | **Login UI activo** (Material 3, email/password validation) |

#### Catalog
| Archivo | Clase / Función |
|---------|----------------|
| `features/catalog/models/catalog_dto.dart` | 8 DTOs: `CatalogPackage`, `CatalogActivityType`, `CatalogEventType`, `CatalogFormField`, `CatalogWorkflowState`, `CatalogWorkflowTransition`, `CatalogEvidenceRule`, `CatalogChecklistTemplate` (614 LOC) |
| `features/catalog/data/catalog_api_repository.dart` | `fetchLatestCatalog(projectId)`, `checkUpdates(projectId, localHash)` |
| `features/catalog/data/catalog_local_repository.dart` | `saveCatalogPackage()`, `getCurrentCatalogVersion()`, `getActivityTypes()`, `getFieldsForActivityType()` |
| `features/catalog/data/catalog_fields_repository.dart` | `getFieldsForActivityType(typeId)` → usada por DynamicFormBuilder |
| `features/catalog/application/catalog_sync_service.dart` | `syncCatalog(projectId)` (check→fetch si necesario→persist), `forceSyncCatalog()` |

#### Activities / Wizard
| Archivo | Clase / Función |
|---------|----------------|
| `features/activities/wizard/wizard_page.dart` | `WizardPage` — orquestador de pasos |
| `features/activities/wizard/wizard_controller.dart` | `WizardController` — state management del wizard |
| `features/activities/wizard/wizard_step_context.dart` | Paso 1: Contexto (proyecto, frente, PK) |
| `features/activities/wizard/wizard_step_fields.dart` | Paso 2: `DynamicFormBuilder` (campos catalog-driven) |
| `features/activities/wizard/wizard_step_evidence.dart` | Paso 3: Evidencias |
| `features/activities/wizard/wizard_step_confirm.dart` | Paso 4: Confirmación + guardado |
| `features/activities/wizard/wizard_validation.dart` | `WizardGatekeeper` — valida antes de avanzar paso |
| `features/activities/wizard/models/dynamic_form_state.dart` | `DynamicFormState` (ChangeNotifier): `setValue()`, `validateAll()`, `getAllValues()` |
| `features/activities/wizard/widgets/dynamic_form_builder.dart` | `DynamicFormBuilder` — widget principal (340 LOC) |
| `features/activities/wizard/widgets/form_field_renderers.dart` | 7 renderers: Text, Number, Date, Select, MultiSelect, Checkbox, TextArea (540 LOC) |

#### Evidence
| Archivo | Clase / Función |
|---------|----------------|
| `features/evidence/services/camera_capture_service.dart` | `CameraCaptureService.capture()` — ImagePicker + metadata |
| `features/evidence/services/gps_tagging_service.dart` | `GpsTaggingService.getCurrentLocation()` — accuracy check |
| `features/evidence/services/image_compression_service.dart` | `ImageCompressionService.compress()` — resize + quality |
| `features/evidence/data/evidence_upload_repository.dart` | `initUpload()`, `completeUpload()` — GCS signed URLs via backend |
| `features/evidence/data/evidence_upload_retry_worker.dart` | Retry worker con exponential backoff |
| `features/evidence/presentation/evidence_capture_page.dart` | `EvidenceCapturePage` — UI captura |
| `features/evidence/presentation/providers/evidence_upload_provider.dart` | Riverpod provider para upload state |

#### Home
| Archivo | Clase |
|---------|-------|
| `features/home/home_page.dart` | `HomePage` — swipe states, dashboard operativo |
| `features/home/models/today_activity.dart` | `TodayActivity`, **`ExecutionState`** (UI-only: pendiente/enCurso/revisionPendiente/terminada) |

#### Sync
| Archivo | Clase / Función |
|---------|----------------|
| `features/sync/models/sync_dto.dart` | `SyncPullRequest`, `SyncPullResponse`, **`ActivityDTO`** (contrato con backend) |
| `features/sync/models/sync_models.dart` | Modelos auxiliares de sync |
| `features/sync/data/sync_api_repository.dart` | `pullActivities(projectId, sinceVersion, limit)` → `POST /sync/pull` |
| `features/sync/data/sync_repository.dart` | Abstracción de repositorio sync |
| `features/sync/services/sync_service.dart` | **`SyncService`** — push logic PENDIENTE de implementar |

#### Agenda
| Archivo | Clase |
|---------|-------|
| `features/agenda/agenda_equipo_page.dart` | `AgendaEquipoPage` — calendario semanal + timeline |
| `features/agenda/models/agenda_item.dart` | `AgendaItem` con `SyncStatus` |
| `features/agenda/models/resource.dart` | `Resource` (operativo asignable) |
| `features/agenda/widgets/dispatcher_bottom_sheet.dart` | `DispatcherBottomSheet` — asignación 3 pasos |
| `features/agenda/widgets/week_strip.dart` | `WeekStrip` — selector semanal |
| `features/agenda/widgets/timeline_list.dart` | `TimelineList` — timeline 7am-7pm |

#### Settings
| Archivo | Clase |
|---------|-------|
| `features/settings/settings_page.dart` | `SettingsPage` — user info, logout, debug panel (4 smoke tests: sync/catalog/evidence) |

### Design System (`ui/`)

**Barrel de imports:** `ui/sao_ui.dart` — un solo import para todo el sistema

#### Tokens de Diseño

| Archivo | Clase | Tokens |
|---------|-------|--------|
| `ui/theme/sao_colors.dart` | `SaoColors` | `primary` (#1565C0), `secondary`, `surface`, `background`, `error`, `warning`, `success`, `info`, `statusPendiente`, `statusEnCurso`, `statusRevision`, `statusCompletada` |
| `ui/theme/sao_typography.dart` | `SaoTypography` | `displayLarge→displaySmall`, `headlineLarge→headlineSmall`, `titleLarge→titleSmall`, `labelLarge→labelSmall`, `bodyLarge→bodySmall` |
| `ui/theme/sao_spacing.dart` | `SaoSpacing` | `xs=4`, `sm=8`, `md=16`, `lg=24`, `xl=32`, `xxl=48` |
| `ui/theme/sao_radii.dart` | `SaoRadii` | `xs=4`, `sm=8`, `md=12` (cards), `lg=16`, `full=999` |
| `ui/theme/sao_shadows.dart` | `SaoShadows` | `card`, `elevated`, `modal` |
| `ui/theme/sao_icons.dart` | `SaoIcons` | Constantes de íconos usados en SAO (no `Icons.*` directo) |
| `ui/theme/sao_motion.dart` | `SaoMotion` | `micro=120ms`, `standard=200ms`, `emphasis=350ms`; curves: `easeOut` |
| `ui/theme/sao_layout.dart` | `SaoLayout` | Breakpoints, maxWidths |
| `ui/theme/sao_theme.dart` | `SaoTheme` | `buildTheme()` → MaterialApp `theme:` |

#### Widgets Reutilizables

| Archivo | Widget | API |
|---------|--------|-----|
| `ui/widgets/sao_button.dart` | `SaoButton` | `.primary()`, `.secondary()`, `.destructive()`, `.ghost()` |
| `ui/widgets/sao_card.dart` | `SaoCard` | `child`, `padding`, `onTap` |
| `ui/widgets/sao_field.dart` | `SaoField` | `label`, `controller`, `validator` |
| `ui/widgets/sao_input.dart` | `SaoInput` | Input raw sin label |
| `ui/widgets/sao_dropdown.dart` | `SaoDropdown` | `items`, `value`, `onChanged` |
| `ui/widgets/sao_activity_card.dart` | `SaoActivityCard` | `activity`, `onSwipe`, `executionState` |
| `ui/widgets/sao_badge.dart` | `SaoBadge` | `label`, `color` |
| `ui/widgets/sao_chip.dart` | `SaoChip` | Filter chip con estado |
| `ui/widgets/sao_panel.dart` | `SaoPanel` | Contenedor con header |
| `ui/widgets/sao_empty_state.dart` | `SaoEmptyState` | `icon`, `title`, `subtitle`, `action` |
| `ui/widgets/sao_alert_card.dart` | `SaoAlertCard` | `type` (warning/info/error), `message` |
| `ui/widgets/special/sao_sync_indicator.dart` | `SaoSyncIndicator` | Estado sync en AppBar |
| `ui/widgets/special/sao_pk_indicator.dart` | `SaoPkIndicator` | Convierte metros → "km+mmm" para display |
| `ui/widgets/special/sao_role_badge.dart` | `SaoRoleBadge` | Badge por rol (ADMIN, COORD, etc.) |
| `ui/widgets/special/sao_metric_card.dart` | `SaoMetricCard` | Dashboard metric |
| `ui/widgets/special/sao_evidence_gallery.dart` | `SaoEvidenceGallery` | Galería de evidencias |
| `ui/widgets/special/sao_project_switcher.dart` | `SaoProjectSwitcher` | Selector de proyecto activo |

#### Helpers

| Archivo | Qué hace |
|---------|---------|
| `ui/helpers/sao_format.dart` | `SaoFormat.pk(meters)` → "142+450"; fechas, duraciones |
| `ui/helpers/sao_validators.dart` | `SaoValidators.required()`, `.email()`, `.pk()` |
| `ui/helpers/sao_platform.dart` | `SaoPlatform.isMobile`, `.isDesktop` |

---

## Desktop Admin — Dart (`desktop_flutter/sao_desktop/lib/`)

| Carpeta | Estado | Notas |
|---------|--------|-------|
| `lib/features/` | ~20% | Solo validation panel + evidence viewer |
| `lib/ui/sao_ui.dart` | ✅ | Mismo design system que mobile |

---

## Tests Móvil (`frontend_flutter/sao_windows/test/`)

| Directorio / Archivo | Cobertura |
|---------------------|-----------|
| `test/features/auth/` | 10 tests — login, logout, bootstrap, token refresh |
| `test/features/catalog/` | — sync service, API repository, local persistence |
| `test/features/activities/wizard/` | 25 tests — DynamicFormBuilder, state, renderers, validation |
| `test/features/evidence/` | 210+ tests — camera, GPS, compresión, upload, retry |
| `test/core/network/` | 15 tests — ApiClient, JWT refresh, error handling |

---

## Load Tests (`load_tests/`)

| Archivo | Qué simula |
|---------|-----------|
| `locust_light_load.py` | 100 usuarios, 5 min, baseline (220 req, 0% failures) |
| `locust_heavy_upload.py` | 500 usuarios, 10 min, GCS stress (9,053 req, 0% failures) |
| `locust_realistic.py` | 1000 usuarios, 30 min (listo si se necesita) |
| `stress_test.js` / `spike_test.js` / `soak_test.js` | k6 scripts (alternativos) |
| `analyze_results.py` | Análisis automático de CSVs de resultados |
| `run_all_tests.ps1` | Orquestador master |
| `results/` | CSVs de los runs ejecutados (light + heavy) |

---

## Archivos de Configuración Raíz

| Archivo | Para qué |
|---------|---------|
| `tools/deploy/deploy_to_cloud_run.ps1` | Deploy completo con gate de smoke test |
| `tools/deploy/verificar_honor.ps1` | Script de verificación |
| `backend/.env` | Variables locales (no commitear) |
| `backend/.env.example` | Template para nuevos devs |
| `backend/pytest.ini` | Config pytest (testpaths, markers) |
| `backend/alembic.ini` | Config Alembic (script_location, sqlalchemy.url) |
| `frontend_flutter/sao_windows/pubspec.yaml` | Dependencias Flutter móvil |
| `frontend_flutter/sao_windows/analysis_options.yaml` | 60+ reglas linter Dart |
| `desktop_flutter/sao_desktop/pubspec.yaml` | Dependencias Flutter desktop |

---

*Generado desde exploración directa del repo — 2026-02-25*
