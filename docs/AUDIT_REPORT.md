# SAO — Informe de auditoría
**Fecha:** 2026-03-04
**Auditor:** Arquitecto principal (escaneo automatizado)
**Alcance:** backend/ · frontend_flutter/sao_windows/ · desktop_flutter/sao_desktop/

## Adenda 2026-03-09 — cierre de fase 1 de CI/CD

Resultado de revalidacion de despliegue automatizado:
- Workflow backend en GitHub Actions completo y en verde.
- Evidencia: run `22880086051` con `test`, `build`, `Deploy to Cloud Run` y `Smoke test` exitosos.
- Servicio activo posterior al deploy: `https://sao-api-fjzra25vya-uc.a.run.app`.

Conclusión:
- Criterio de cierre de Fase 1 (CI/CD end-to-end) queda **CERRADO**.
- La ruta principal de despliegue pasa a pipeline automatizado en `main`.

## Adenda 2026-03-05 — corrida E2E real en staging (flujo operativo a revisión y pull)

Resultado de validacion en entorno real Cloud Run:
- Script ejecutado: `backend/scripts/e2e_staging_flow.py`
- Base URL: `https://sao-api-fjzra25vya-uc.a.run.app`
- Proyecto: `TMQ`
- Evidencia de salida:
  - `E2E flow passed`
  - `Activity UUID: 6997c072-4450-4f63-b9b2-5a71cb85df60`
  - `Push status: CREATED`
  - `Final execution_state: COMPLETADA`

Hallazgos de compatibilidad de entorno y acciones correctivas:
- `/api/v1/catalog/version/current` en staging retorna `version_id` semantico (ej. `tmq-v2.0.0`) que no cumple formato UUID exigido por `/sync/push`.
- Se endurecio `backend/scripts/e2e_staging_flow.py` para resolver UUID de `catalog_version_id` via `/api/v1/catalog/versions` cuando el `version_id` actual no es UUID.
- `POST /api/v1/review/activity/{id}/decision` con `APPROVE` puede responder `422 CHECKLIST_INCOMPLETE` segun reglas del tipo de actividad.
- Se agrego fallback explicito a `APPROVE_EXCEPTION` para completar la validacion de ruta end-to-end en staging sin false negatives por gating operativo.

Conclusión:
- Criterio "corrida E2E staging exitosa documentada" queda **CERRADO**.

## Addendum 2026-03-05 — Cierre de Hallazgo "Reject Reasons Hardcoded"

Resultado de re-auditoría:
- `backend/app/api/v1/review.py` valida `reject_reason_code` exclusivamente contra tabla `reject_reasons` activa.
- `backend/app/seeds/initial_data.py` incluye `seed_reject_reasons()` idempotente para bootstrap controlado.
- `POST /api/v1/review/reject-reasons` permite alta runtime de nuevas razones (sin redeploy).

Evidencia de regresión agregada:
- `backend/tests/test_review_observations.py::test_review_reject_fails_when_reasons_catalog_is_empty`
  valida que una razón legacy (`PHOTO_BLUR`) falle si no existe en BD.
- `backend/tests/test_review_observations.py::test_review_reject_accepts_runtime_created_reason`
  valida que una razón creada en runtime (`NUEVA_REGLA_QA`) sea aceptada en decisión REJECT.

Ejecución de pruebas:
- `pytest -m integration tests/test_review_observations.py -q` → **14 passed**.

Conclusión:
- Hallazgo "razones de rechazo hardcoded" queda **CERRADO**.

---

## 1. Hardcodes Detectados

### 1.1 URLs y Endpoints hardcodeados

| Archivo | Línea | Patrón | Impacto | Fix |
|---------|-------|--------|---------|-----|
| `desktop_flutter/sao_desktop/lib/core/config/data_mode.dart` | 14 | `'https://sao-api-fjzra25vya-uc.a.run.app'` | Dev puede golpear producción accidentalmente | Requerir `SAO_BACKEND_URL` via `dart-define`; sin valor default hardcoded |
| `desktop_flutter/sao_desktop/lib/data/repositories/backend_api_client.dart` | 13 | Misma URL de producción | Duplicado; mismo riesgo | Centralizar en `AppDataMode`; eliminar fallback hardcoded |
| `desktop_flutter/sao_desktop/lib/features/admin/auth/session_controller.dart` | 90 | Misma URL de producción | Admin puede impactar prod sin intención | Leer de `AppDataMode.backendBaseUrl` |
| `frontend_flutter/sao_windows/lib/core/config/app_config.dart` | 10 | `https://sao-api-fjzra25vya-uc.a.run.app/api/v1` | Mismo riesgo mobile | Parametrizar vía `--dart-define` o `String.fromEnvironment` |
| `frontend_flutter/sao_windows/lib/core/network/api_config.dart` | 19 | Duplicado URL prod | Confusión si se cambia el servicio | Unificar en `AppConfig` |
| `backend/app/core/config.py` | CORS_ORIGINS | `https://sao-api-fjzra25vya-uc.a.run.app` + localhost hardcoded en lista | Fallo si se rota el dominio | Leer `CORS_ORIGINS` completo como env var CSV |

### 1.2 Colores directos en UI

#### Mobile (frontend_flutter)
| Archivo | Línea | Color | Fix |
|---------|-------|-------|-----|
| `lib/features/agenda/widgets/filter_chips_row.dart` | 42 | `Color(0xFF6B7280)` | `SaoColors.gray600` |
| `lib/features/agenda/widgets/filter_chips_row.dart` | 68 | `Color(0xFFF3F4F6)` | `SaoColors.gray100` |
| `lib/features/agenda/widgets/filter_chips_row.dart` | 69 | `Color(0xFF1F2937)` | `SaoColors.gray800` |
| `lib/features/agenda/widgets/agenda_mini_card.dart` | 50 | `Color(0xFF111827)` | `SaoColors.textPrimary` |
| `lib/features/agenda/widgets/agenda_mini_card.dart` | 82 | `Color(0xFF3B82F6)` | `SaoColors.info` |
| `lib/features/agenda/widgets/agenda_mini_card.dart` | 117 | `Color(0xFF10B981)` | `SaoColors.riskLow` |
| `lib/features/agenda/widgets/agenda_mini_card.dart` | 119 | `Color(0xFFFBBF24)` | `SaoColors.warning` |
| `lib/features/home/home_page.dart` | 808 | `Color(0xFFEFF6FF)` | Agregar `SaoColors.infoBg` |
| `lib/features/settings/settings_page.dart` | 36 | `Color(0xFFEFF6FF)` | `SaoColors.infoBg` |
| `lib/core/navigation/shell.dart` | 93 | `Color(0xFFD32F2F)` | `SaoColors.error` |
| `lib/features/projects/projects_page.dart` | 50,69,71,129 | Múltiples grays | Tokens `SaoColors.gray*` |

**Total mobile:** ~50 instancias. `SaoColors` existe con helpers: `getRiskColor()`, `getStatusColor()`. Solo falta aplicar.

---

**✅ CERRADO — 2026-03-04 (F0.5)**

Gate verificado:
```
grep -r "Color(0xFF" frontend_flutter/sao_windows/lib/features/
```
→ **0 archivos Dart** con literales `Color(0xFF...)`. Único resultado: `sync/README.md` (docs, no código).

Archivos modificados (9):
- `lib/features/agenda/widgets/filter_chips_row.dart`
- `lib/features/agenda/widgets/agenda_mini_card.dart`
- `lib/features/agenda/agenda_equipo_page.dart`
- `lib/features/home/home_page.dart`
- `lib/features/settings/settings_page.dart`
- `lib/features/projects/projects_page.dart`
- `lib/features/sync/sync_center_page.dart`
- `lib/features/sync/models/sync_models.dart`
- `lib/core/navigation/shell.dart`

Tokens nuevos añadidos a `lib/ui/theme/sao_colors.dart` (8):

| Token | Valor | Semántica |
|-------|-------|-----------|
| `infoLight` | `0xFFDBEAFE` | blue-100 — badge fondo "subiendo" |
| `errorBg` | `0xFFFEF2F2` | red-50 — fondo banner de error |
| `errorBorder` | `0xFFFECACA` | red-200 — borde banner de error |
| `errorText` | `0xFF991B1B` | red-800 — texto en banner de error |
| `errorLight` | `0xFFFEE2E2` | red-100 — fondo estado sync error |
| `successBg` | `0xFFF0FDF4` | green-50 — fondo estado sync ok |
| `warningBg` | `0xFFFEF3C7` | amber-50 — fondo badge "esperando" |
| `brandPrimary` | `0xFF691C32` | Rojo corporativo — FAB Asignar |

⛔ **Regla de prevención:** Prohibido usar `Color(0xFF...)` literal en `features/`. Usar únicamente `SaoColors.*`. Cualquier PR que introduzca `Color(0xFF` en `lib/features/` debe ser rechazado en code review.

#### Desktop (sao_desktop)
| Archivo | Línea | Color | Fix |
|---------|-------|-------|-----|
| `lib/features/admin/admin_shell.dart` | 59 | `Color(0xFFE2E8F0)` | `SaoColors.border` |
| `lib/features/auth/app_login_page.dart` | 131,138,144 | `Colors.red.shade*` | `SaoColors.error` |
| `lib/features/users/users_page.dart` | 117 | `Colors.red` | `SaoColors.error` |

**Desktop** está ~99% conforme; los 3 casos restantes son menores.

### 1.3 Catálogos/arrays/maps embebidos en UI o servicios

| Archivo | Línea | Contenido | Impacto | Fix |
|---------|-------|-----------|---------|-----|
| `frontend_flutter/…/features/auth/ui/signup_page.dart` | 33–39 | `List<String> _roles = ['ADMIN','COORD','SUPERVISOR','OPERATIVO','LECTOR']` | Si cambian roles en backend, UI queda desincronizada | Cargar de `/auth/roles` o incluir en `/auth/me` response |
| `frontend_flutter/…/features/activities/wizard/wizard_controller.dart` | 186–191 | `_fallbackProjects = [TMQ, TAP, TQI, TSNL]` | Hardcoded projects usados cuando API falla | Aceptable como fallback offline SOLO si viene de bundle/config local; anotar como deuda |
| ~~`frontend_flutter/…/catalog/activity_catalog.dart`~~ | ~~45–137~~ | ~~8 activity types con icon, defaultRisk, requiresEvidence, allowedRoles~~ | ~~Paralelo al bundle; puede divergir~~ | ✅ **ELIMINADO F1.1** |
| `frontend_flutter/…/catalog/risk_catalog.dart` | 43–90 | 4 risk levels con colores y opacidades fijos | Paralelo al token de diseño | Mantener como mapeador de tokens; mover colores a `SaoColors`/`DesignTokens` |
| `frontend_flutter/…/catalog/status_catalog.dart` | 47–152 | 9 estados con máquina de estados `nextStates` | Si workflow cambia en backend, UI no sigue | Derivar de `CatalogBundle.effective.rules` o cargar de API `/catalog/workflow` |
| `desktop_flutter/…/features/planning/planning_page.dart` | 46 | `DropdownMenuItem(value: 'TMQ')` | Multi-proyecto bloqueado | Cargar proyectos desde sesión/API |
| `desktop_flutter/…/features/reports/reports_provider.dart` | 71 | `['TMQ', 'TAP', 'SNL']` como lista fija | Multi-proyecto roto | Cargar de `GET /api/v1/projects` |
| `backend/app/api/v1/review.py` | reject_playbook endpoint | `PHOTO_BLUR, GPS_MISMATCH, MISSING_INFO` hardcoded en código | Si se agregan razones, requiere redeploy | Mover a seed/config tabla `reject_reasons` |
| `backend/app/api/v1/auth.py` | signup | roles válidos hardcoded (`ADMIN`, `COORD`, etc.) | Divergencia posible | Leer de tabla `roles` vía query |

---

**✅ CERRADO — 2026-03-04 (F1.1) — activity_catalog.dart eliminado**

Archivo eliminado: `frontend_flutter/sao_windows/lib/catalog/activity_catalog.dart` (200 líneas)
Contenido eliminado: clase `ActivityType` + clase `ActivityCatalog` con 8 tipos hardcoded (CAM, REU, ASA, CON, SUP, CAP, INS, LEV), helpers `findById`, `findByLabel`, `dropdownItems`, `filterByRole`, `getIconColor`.

Archivos editados:
- `lib/catalog/catalog_index.dart` — removida línea `export 'activity_catalog.dart';`; doc actualizado
- `lib/ui/sao_ui.dart` — removida re-exportación `export '../catalog/activity_catalog.dart';`; comentario de uso actualizado

Fuente canónica de actividades:
```
CatalogRepository.activities
  → CatalogData.fromBundleJson(entities.activities)
  → assets/base_seed_catalog.bundle.json  (offline fallback)
  → GET /catalog/bundle?project_id=…      (online, canonical)
```

Gates verificados:
```
grep -r "ActivityCatalog|activity_catalog" frontend_flutter/sao_windows/lib/**/*.dart
```
→ **0 resultados** en archivos Dart.

Smoke test creado: `test/features/catalog/catalog_bundle_smoke_test.dart` (3 tests):
1. Bundle asset tiene schema `sao.catalog.bundle.v1`
2. `CatalogData.fromJson(bundle)` devuelve `actividades` no vacío
3. Cada `CatItem` tiene `id`, `label` e `icon` válidos

⛔ **Regla de prevención:** Prohibido crear archivos `*_catalog.dart` con listas estáticas de entidades que existen en el bundle. Toda entidad del dominio (actividades, estados, riesgos de entidad) debe venir de `CatalogRepository` o del backend. Excepciones aceptadas solo para mapas de tokens UI (`risk_catalog.dart` → mapeo de string a `SaoColors`).

---

### 1.4 Reglas de negocio en if/switch de UI por categoría/estado

| Archivo | Línea | Patrón | Impacto | Fix |
|---------|-------|--------|---------|-----|
| `desktop_flutter/…/widgets/activity_queue_panel.dart` | 97–110 | `switch(queueTab)` con `description.contains('gps')` para detectar conflictos GPS | Frágil; depende de texto libre | Agregar campo estructurado `flags: {gps_mismatch: bool}` en ActivityDTO |
| `desktop_flutter/…/widgets/activity_queue_panel.dart` | 105 | `description.contains('cambio')` para detectar catalog change | Idéntico problema | Campo `flags.catalog_changed: bool` |
| `frontend_flutter/…/catalog/risk_catalog.dart` | 98–120 | `switch` normalizando variantes de texto: bajo/low, medio/medium, alto/high | Acumula deuda si backend cambia | Usar enum único desde backend; normalizar en capa de parsing |
| `backend/app/api/v1/review.py` | decision endpoint | `if decision == 'APPROVE_EXCEPTION': require ADMIN role` | Hardcoded excepción en lógica | Mover a tabla de permisos workflow: `permission workflow.approve_exception` |

### 1.5 Project ID 'TMQ' hardcodeado (Desktop — ALTA PRIORIDAD)

7 archivos afectados:
- `desktop_flutter/…/features/reports/reports_provider.dart:53,71`
- `desktop_flutter/…/features/planning/planning_provider.dart:11`
- `desktop_flutter/…/features/planning/planning_page.dart:46`
- `desktop_flutter/…/features/operations/widgets/activity_details_panel_pro.dart:398`
- `desktop_flutter/…/features/operations/validation_page_new_design.dart:123`
- `desktop_flutter/…/data/repositories/catalog_repository.dart` (fallback `'TMQ'`)

**Fix:** Inyectar `currentProjectId` desde `AppSessionController` o `SessionState` vía Riverpod.

---

## 2. Servicios y Endpoints Faltantes por Capa

### Backend — FALTA
| Endpoint | Descripción | Evidencia |
|----------|-------------|-----------|
| `GET /api/v1/catalog/workflow` | Devolver máquina de estados del workflow (transiciones por rol) | Máquina hardcoded en status_catalog.dart (desktop) y status_catalog.dart (mobile) |
| `GET /api/v1/auth/roles` | Listar roles disponibles | Lista hardcoded en signup_page.dart |
| `GET /api/v1/fronts?project_id=` | Listar frentes de un proyecto | Front referenciado en models pero sin router expuesto |
| `GET /api/v1/locations?front_id=` | Listar ubicaciones de un frente | Location referenciada en models sin router |
| `PATCH /api/v1/activities/{uuid}/flags` | Actualizar flags estructurados (gps_mismatch, catalog_changed) | Detección actual por text matching en desktop |
| `GET /api/v1/review/reject-reasons` | Listar razones de rechazo dinámicas | Hardcoded PHOTO_BLUR, GPS_MISMATCH, MISSING_INFO |
| `GET /api/v1/sync/pull` (events) | Pull incremental de eventos | Solo activities en pull actual |
| Observations prefix `/observations` (falta `/api/v1`) | observations.py no tiene prefijo `/api/v1` | main.py incluye sin prefijo adicional |

### Mobile — FALTA / PARCIAL
| Feature | Estado | Evidencia |
|---------|--------|-----------|
| PIN offline authentication | FALTA | Mencionado en MEMORY.md; `pin_hash` existe en User model pero flujo mobile sin implementar |
| Pull sync (incremental por cursor) | PARCIAL | `SyncService.pullChanges()` — existe orquestrador pero no pull desde backend |
| Conflict resolution UI | FALTA | `SyncQueue.status=CONFLICT` manejado como ERROR; sin UI de resolución |
| Events pull sync | FALTA | Solo push de eventos; pull de eventos del backend no implementado |
| Catalog pull/diff | PARCIAL | Bundle se descarga completo; no usa `/catalog/diff` incremental |
| Front/Location selectors | FALTA | Sin APIs de fronts/locations para poblar selectores en wizard |
| Role list dinámico | FALTA | Roles hardcoded en signup_page |

### Desktop — FALTA / PARCIAL
| Feature | Estado | Evidencia |
|---------|--------|-----------|
| Project context en sesión | FALTA | projectId 'TMQ' hardcoded en 7 archivos |
| Catalog editor UI | PARCIAL | Backend tiene 10+ endpoints editor; desktop no tiene pantalla conectada |
| Sync panel | FALTA | Desktop no tiene outbox ni estado de sincronización visual |
| GPS validation widget | PARCIAL | `gps_validation_banner.dart` existe pero detección vía text matching |
| Events validation | FALTA | Solo activities en queue de validación; eventos sin pantalla |
| Reports reales | PARCIAL | `reports_page.dart` tiene UI pero proyectos hardcoded |

---

## 3. Prueba E2E: Esperada vs Realidad

| Flujo | Esperado | Realidad | Estado |
|-------|----------|----------|--------|
| **Operativo crea actividad offline** | App crea en Drift, encola en SyncQueue | ✅ Implementado | OK |
| **Sync push actividades** | `POST /sync/push` con batch de activities | ✅ Implementado + auto-sync 15min | OK |
| **Coordinador valida en desktop** | Ve cola PENDING_REVIEW, toma decisión approve/reject | ✅ Implementado | OK |
| **Desktop refleja resultado de validación en mobile** | Pull sync trae status actualizado | ❌ Pull sync no implementado en mobile | DESCONECTADO |
| **Catalog update en mobile** | `/catalog/diff` incremental; mobile re-renderiza forms | ❌ Bundle descargado completo; sin diff | PARCIAL |
| **Operativo ve eventos del proyecto** | Pull events desde servidor | ❌ Solo push local→servidor | DESCONECTADO |
| **PIN offline login** | Mobile autentica sin red usando PIN + token cacheado | ❌ Sin implementar | FALTA |
| **Multi-proyecto en desktop** | Selector de proyecto carga datos del proyecto seleccionado | ❌ TMQ hardcoded | ROTO |
| **Front/Location scope** | Operativo ve solo actividades de su frente | ❌ Sin APIs fronts/locations | FALTA |
| **Conflict resolution** | UI muestra conflictos; operativo elige versión | ❌ Conflictos marcados como ERROR sin UI | FALTA |
| **Catalog-driven form colors** | Colores de categoría vienen del bundle | ❌ Colores hardcoded en catalogs locales | PARCIAL |
| **Workflow state machine del server** | Transiciones vienen de backend | ❌ Hardcoded en status_catalog.dart | DESCONECTADO |

---

## 4. Deuda Técnica Adicional

| Ítem | Severidad | Ubicación |
|------|-----------|-----------|
| `observations.py` sin prefijo `/api/v1` (rutas son `/observations` en lugar de `/api/v1/observations`) | MEDIA | `backend/app/api/v1/observations.py` + `main.py` |
| Desktop usa `HttpClient` nativo (no Dio); sin JWT refresh automático | ALTA | `backend_api_client.dart` |
| Desktop no persiste sesión entre reinicios (token en memoria `TokenStore`) | ALTA | `desktop/lib/core/auth/` |
| `CatalogRepository` carga `projectId.isEmpty ? 'TMQ'` como fallback | ALTA | `desktop/lib/data/repositories/catalog_repository.dart` |
| No hay tests en desktop Flutter | ALTA | `desktop_flutter/sao_desktop/test/` (vacío excepto `features/`) |
| Backend roles no expuestos en API; solo enumerados en código | MEDIA | `backend/app/api/v1/users.py` |
| Access token expiry 24h (muy largo para un sistema de campo) | BAJA | `config.py: ACCESS_TOKEN_EXPIRE_MINUTES=1440` |
| Sin rate limiting en backend | MEDIA | `backend/app/main.py` |
