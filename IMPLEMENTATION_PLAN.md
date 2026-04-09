# SAO — Implementation Plan (Cierre del Sistema)
**Versión:** 2.0.0 | **Fecha:** 2026-03-04
**Basado en:** Auditoría integral del repositorio (docs/AUDIT_REPORT.md)

---

## Resumen de Fases

| Fase | Nombre | Duración | Gate de Aceptación |
|------|--------|----------|--------------------|
| F0 | Auditoría + Fixes Críticos | 2 días | Todos los tests pasan; prefix /api/v1 en observations; 0 hardcodes TMQ en desktop |
| F1 | Catálogo Fuente Única | 1 semana | Bundle es la única fuente de tipos, colores, workflow |
| F2 | Workflow + Trazabilidad | 1 semana | Checklist por tipo; timeline expuesto; reject reasons dinámicas |
| F3 | Sync Offline Real | 2 semanas | Pull sync, conflictos con UI, diff catálogo |
| F4 | Evidencias + Calidad | 1 semana | Checklist de evidencias por tipo; validación GPS estructurada |
| F5 | Endurecimiento | 1 semana | PIN offline, rate limiting, tests E2E, desktop JWT refresh |

---

## F0 — Auditoría + Fixes Críticos
**Duración:** 2 días
**Objetivo:** Eliminar bloqueadores inmediatos sin cambios de arquitectura.

### Tareas

#### F0.1 Backend — Fix observations prefix (30 min)
**Archivos:** `backend/app/main.py`, `backend/app/api/v1/observations.py`
- Agregar `prefix="/api/v1"` al router de observations en `main.py`.
- Verificar que las rutas sean `/api/v1/observations`, `/api/v1/mobile/observations`.
- Actualizar tests en `tests/test_review_observations.py`.

**Criterio de aceptación:** `pytest tests/test_review_observations.py -q` → todos pasan.

#### F0.2 Desktop — Eliminar hardcode 'TMQ' (2h)
**Archivos:**
- `desktop_flutter/sao_desktop/lib/features/reports/reports_provider.dart`
- `desktop_flutter/sao_desktop/lib/features/planning/planning_provider.dart`
- `desktop_flutter/sao_desktop/lib/features/planning/planning_page.dart`
- `desktop_flutter/sao_desktop/lib/features/operations/widgets/activity_details_panel_pro.dart`
- `desktop_flutter/sao_desktop/lib/features/operations/validation_page_new_design.dart`
- `desktop_flutter/sao_desktop/lib/data/repositories/catalog_repository.dart`

**Solución:**
1. Agregar `currentProjectId` al `SessionState` / `AppUser`.
2. En `AppSessionController.login()` → guardar `projects.first` como proyecto activo.
3. Exponer `sessionProvider.currentProjectId` vía Riverpod.
4. Reemplazar todos los `'TMQ'` por `ref.read(sessionProvider).currentProjectId`.
5. Agregar selector de proyecto en shell/header para cambiar proyecto activo.

**Criterio de aceptación:** 0 instancias de `'TMQ'` hardcoded fuera de seeds/tests.

#### F0.3 Backend — CORS desde env var (30 min)
**Archivos:** `backend/app/core/config.py`, `backend/app/main.py`
- Cambiar `CORS_ORIGINS` a lectura de env var CSV completa.
- Eliminar URL hardcoded de Cloud Run del código fuente.

**Criterio de aceptación:** `grep -r "sao-api-fjzra25vya" backend/app/` → 0 resultados.

#### F0.4 Desktop — Backend URL sin hardcode (30 min)
**Archivos:**
- `desktop_flutter/sao_desktop/lib/core/config/data_mode.dart`
- `desktop_flutter/sao_desktop/lib/data/repositories/backend_api_client.dart`
- `desktop_flutter/sao_desktop/lib/features/admin/auth/session_controller.dart`

**Solución:** Eliminar fallback con URL hardcoded. Requiere `--dart-define=SAO_BACKEND_URL=...` explícito. Sin `dart-define`: lanzar error claro en startup.

**Criterio de aceptación:** App lanza error útil si `SAO_BACKEND_URL` no está definida en modo release.

#### F0.5 Mobile — Color hardcodes (2h)
Ver AUDIT_REPORT.md §1.2 y DESIGN_TOKENS.md §6. Reemplazar ~50 instancias con tokens `SaoColors.*`.

**Criterio de aceptación:** `grep -r "Color(0xFF" frontend_flutter/sao_windows/lib/features/` → 0 resultados.

---

**Riesgos F0:**
- Observations prefix puede afectar clientes existentes → revisar si desktop llama `/observations` directo.
- Selector de proyecto en desktop requiere `GET /projects` con auth → verificar que desktop tiene token válido.

---

## F1 — Catálogo Fuente Única
**Duración:** 1 semana
**Objetivo:** El bundle del catálogo es la **única** fuente de tipos de actividad, colores, y máquina de estados.

### Tareas

#### F1.1 Mobile — Eliminar activity_catalog.dart local
**Archivos:**
- `frontend_flutter/sao_windows/lib/catalog/activity_catalog.dart` → **eliminar**
- Todos los usos en features/ → reemplazar por `CatalogRepository.data.activities`

**Criterio de aceptación:** Archivo eliminado; app renderiza formularios desde bundle sin regresión.

#### F1.2 Mobile — status_catalog.dart catalog-driven
**Archivos:** `frontend_flutter/sao_windows/lib/catalog/status_catalog.dart`
- Mantener helpers de UI (colors, labels) pero mover `nextStates` a lectura desde `bundle.effective.rules.workflow`.
- Agregar método `StatusCatalog.nextStatesFor(status, role)` que lee del bundle.

**Criterio de aceptación:** Cambiar `nextStates` en bundle → mobile refleja cambio sin redeploy.

#### F1.3 Desktop — status_catalog.dart catalog-driven (mismo que F1.2)
**Archivos:** `desktop_flutter/sao_desktop/lib/catalog/status_catalog.dart`

#### F1.4 Backend — `GET /catalog/workflow`
**Archivos:** `backend/app/api/v1/catalog.py`
- Agregar endpoint `GET /catalog/workflow?project_id=TMQ`.
- Devuelve la máquina de estados del bundle actual (extraída de `effective.rules.workflow`).

**Criterio de aceptación:** Endpoint existe; clientes pueden consumirlo.

#### F1.5 Mobile — roles dinámicos
**Archivos:** `frontend_flutter/sao_windows/lib/features/auth/ui/signup_page.dart`
- Llamar `GET /auth/roles` (nuevo) o incluir roles en respuesta de `GET /auth/me`.
- Eliminar lista hardcoded `_roles`.

**Backend requerido:** `GET /api/v1/auth/roles` → `["ADMIN","COORD","SUPERVISOR","OPERATIVO","LECTOR"]`

#### F1.6 Bundle — agregar color_tokens y form_fields
**Archivos:** `backend/app/services/catalog_bundle_service.py`, seeds
- Incluir `color_tokens` y `form_fields` en el bundle serializado.
- Actualizar `CatalogBundleModels` en mobile y desktop para deserializarlos.

**Criterio de aceptación:** `GET /catalog/bundle` incluye `effective.color_tokens` y `effective.form_fields`.

---

**Riesgos F1:**
- Eliminar `activity_catalog.dart` puede descubrir usos implícitos; hacer grep antes de eliminar.
- Workflow desde bundle requiere coordinación backend + mobile en mismo sprint.

---

## F2 — Workflow + Trazabilidad
**Duración:** 1 semana
**Objetivo:** Checklist por tipo de actividad; historial expuesto; razones de rechazo dinámicas.

### Tareas

#### F2.1 Backend — Checklist validation por tipo
- Agregar validación en `POST /review/activity/{id}/decision` (approve):
  - Verificar que la actividad tiene las evidencias mínimas requeridas según `bundle.effective.entities.activities[type].workflow_checklist`.
  - Si falta algún ítem → retornar 422 con detalle de qué falta.

#### F2.2 Backend — Timeline de actividad
**Archivos:** nuevo endpoint `GET /api/v1/activities/{uuid}/timeline`
- Devuelve `audit_logs` filtrado por `entity_id = uuid`, ordenado por `created_at`.
- Incluye: actor, acción, timestamp, detalles.

#### F2.3 Backend — Reject reasons dinámicas
**Archivos:** nueva tabla `reject_reasons` o seed JSON
- Mover `PHOTO_BLUR`, `GPS_MISMATCH`, `MISSING_INFO` a tabla/seed.
- `GET /review/reject-playbook` lee de BD en lugar de array hardcoded.
- Agregar endpoint `POST /review/reject-reasons` (ADMIN) para agregar nuevas razones.

#### F2.4 Desktop — Timeline en ValidationPage
- Agregar panel "Historial" en validation detail view.
- Llamar `GET /activities/{uuid}/timeline`.

#### F2.5 Backend + Desktop — Activity flags estructurados
**Archivos:** `backend/app/schemas/activity.py`, `desktop/lib/widgets/activity_queue_panel.dart`
- Agregar campo `flags: { gps_mismatch: bool, catalog_changed: bool }` en `ActivityDTO`.
- Backend lo calcula al crear/actualizar actividad.
- Desktop filtra por `flags.gps_mismatch` en lugar de `description.contains('gps')`.

---

**Riesgos F2:**
- Checklist validation puede rechazar actividades históricas válidas → aplicar solo a actividades creadas post-F2.
- Timeline puede ser costoso en BD → limitar a últimas 50 acciones.

---

## F3 — Sync Offline Real
**Duración:** 2 semanas
**Objetivo:** Pull sync completo, resolución de conflictos con UI, diff incremental de catálogo.

### Tareas

#### F3.1 Mobile — Pull sync implementación real
**Archivos:** `lib/core/sync/sync_orchestrator.dart`, `lib/features/sync/services/sync_service.dart`
- Implementar `pullChanges(projectId)`:
  - `POST /sync/pull { project_id, since_version: N }`
  - Upsert activities en Drift con `localRevision` y `serverRevision`.
  - Guardar nuevo cursor en `SyncMetadata`.
  - Manejar paginación (`has_more`).

#### F3.2 Mobile — Pull incremental de eventos
- Agregar `GET /events?project_id=TMQ&since_version=N` al backend.
- Implementar pull de eventos en `SyncService`.
- Guardar en `LocalEvents` table.

#### F3.3 Mobile — UI de resolución de conflictos
- Dialog al detectar conflicto: mostrar diff entre versión local y servidor.
- Opciones: "Usar mi versión" (reenviar con `force_override`) o "Usar versión del servidor" (pull activo).
- Backend: soportar `force_override: true` en push.

#### F3.4 Mobile — Diff incremental de catálogo
- Implementar `syncCatalog()` en `CatalogRepository`:
  - `GET /catalog/check-updates?project_id=TMQ&hash={localHash}`.
  - Si `update_available`: descargar diff o bundle completo según backend response.

#### F3.5 Desktop — Outbox básico
- Desktop actualmente no tiene sync offline. Si pierde conexión, operaciones fallan.
- Agregar queue en memoria con retry para decisiones de review.
- **No requiere Drift en desktop** — queue en memoria es suficiente para las sesiones cortas.

---

**Riesgos F3:**
- Pull sync puede traer muchos registros en primera corrida → implementar paginación desde el inicio.
- Conflictos simultáneos (mismo UUID editado por 2 usuarios) → backend ya retorna CONFLICT; gestión en mobile.

---

## F4 — Evidencias + Calidad de Datos
**Duración:** 1 semana
**Objetivo:** Validación de calidad de evidencias; GPS obligatorio por tipo.

### Tareas

#### F4.1 Mobile — GPS validation en wizard
- Si `requires_gps` en bundle para el tipo de actividad → capturar GPS obligatorio.
- Mostrar error si GPS no disponible.
- Guardar `latitude`, `longitude` en activity.

#### F4.2 Backend — Validación GPS en review
- En `GET /review/queue` → calcular y devolver `gps_mismatch` automáticamente.
- Comparar `activity.latitude/longitude` con `front` PKs esperados.

#### F4.3 Mobile + Desktop — Evidencias mínimas por tipo
- Leer `workflow_checklist.photo_min_N` del bundle.
- Mobile: no permitir submit si no se cumplen mínimos.
- Desktop: mostrar indicator en review queue si falta evidencia.

#### F4.4 Backend — Compresión/validación de imágenes
- Validar `mime_type` en `upload-init` (solo JPEG, PNG, PDF permitidos).
- Límite de tamaño: 20MB por archivo.

---

## F5 — Endurecimiento
**Duración:** 1 semana
**Objetivo:** PIN offline, rate limiting, tests E2E, desktop JWT refresh.

### Tareas

#### F5.1 Mobile — PIN offline login
- Al hacer login exitoso: solicitar al usuario crear PIN de 4-6 dígitos.
- `PUT /api/v1/auth/me/pin { pin: "1234" }` → backend hashea y guarda en `user.pin_hash`.
- Al estar offline: mostrar pantalla PIN → validar contra hash local (bcrypt).
- Expirar sesión PIN a las 8h para forzar re-auth online.

#### F5.2 Backend — Rate limiting
- Agregar `slowapi` o middleware de rate limiting en FastAPI.
- Límites: 100 req/min global; 10 req/min en `/auth/login`.

#### F5.3 Desktop — JWT auto-refresh
- Reemplazar `HttpClient` nativo por `Dio` en `backend_api_client.dart`.
- Agregar interceptor de refresh idéntico al de mobile.
- Persistir token entre reinicios (usar `flutter_secure_storage`).

#### F5.4 Tests E2E
- Definir y ejecutar flujo E2E completo:
  1. Operativo crea actividad offline.
  2. Sync push → backend.
  3. Coordinador aprueba en desktop.
  4. Pull sync → mobile ve estado aprobado.
- Ejecutar en entorno staging antes de merge a main.

#### F5.5 Mobile — Fronts y Locations
- Backend: exponer `GET /fronts?project_id=TMQ` y `GET /locations?front_id=X`.
- Mobile: cargar y cachear en Drift.
- Wizard: selector de frente → selector de ubicación cascadeado.

---

## Gates de Aceptación por Fase

| Fase | Criterio obligatorio |
|------|---------------------|
| F0 | `pytest backend/tests -q` → todos pasan; 0 hardcodes TMQ en desktop; 0 Color(0xFF) en features/ |
| F1 | `GET /catalog/bundle` incluye `color_tokens` + `form_fields`; `activity_catalog.dart` eliminado |
| F2 | `GET /activities/{uuid}/timeline` devuelve historial; reject_reasons desde BD |
| F3 | Pull sync produce actividades actualizadas; conflicto muestra dialog en mobile |
| F4 | Submit mobile rechazado si GPS faltante en tipo que lo requiere |
| F5 | E2E completo pasa en staging; desktop auto-refreshes token |

---

## Addendum 2026-03-24 - Mejora del Flujo del Sistema

**Contexto:** El plan F0-F5 resolvio la mayor parte de la deuda funcional y tecnica base. El siguiente salto no es agregar modulos aislados, sino endurecer el flujo operativo completo para que asignacion, captura, sync y revision formen una sola historia de negocio.

**Objetivo del addendum:** mejorar la claridad del flujo para operativo y coordinacion, reducir estados ambiguos y volver accionables los errores de sync y las devoluciones de revision.

### Enfoque

1. Separar de forma explicita estado operativo, estado de sync y estado de revision.
2. Redisenar la experiencia visible alrededor de tareas y no de estados tecnicos.
3. Hacer recuperable el wizard en cualquier paso con guardado incremental.
4. Estructurar la devolucion de revision para que sea corregible en un solo ciclo.
5. Medir el flujo con KPIs operativos y no solo con conteos tecnicos.

### Lineas de trabajo

| Prioridad | Linea | Resultado esperado |
|-----------|-------|--------------------|
| P0 | Contrato unico de flujo | Backend, mobile y desktop consumen la misma proyeccion de estado |
| P1 | Home + Sync Center orientados a tareas | El operativo siempre ve su siguiente accion |
| P1 | Wizard incremental y recuperable | Ningun avance se pierde y el sistema explica faltantes |
| P1 | Revision estructurada | La devolucion llega con motivo, campo afectado y accion sugerida |
| P2 | Asignacion y visibilidad robustas | Ninguna actividad desaparece por detalles de sync o assignee |
| P2 | KPIs operativos | Dashboard y reportes muestran salud real del flujo |

### Entregables canonicos

- `docs/PLAN_MEJORA_FLUJO_2026-03-24.md` - plan ejecutivo y tecnico de mejora del flujo.
- `docs/BACKLOG_MEJORA_FLUJO_2026-03-24.md` - backlog tecnico accionable por capa y carpeta del repositorio.

### Criterios de exito

1. El operativo puede identificar su siguiente accion sin interpretar estados internos.
2. Una actividad puede seguirse sin ambiguedad desde asignacion hasta aprobacion.
3. Los errores de sync informan causa, reintento automatico y accion manual si aplica.
4. Las devoluciones de revision llegan como correcciones accionables y no como texto libre ambiguo.
5. Dashboard y reportes se alimentan de KPIs del flujo, no solo de la cola de revision.

### Secuencia recomendada

1. Sprint 1: contrato unico de flujo + Home/Sync Center orientados a tareas.
2. Sprint 2: wizard incremental + devolucion estructurada de revision.
3. Sprint 3: endurecimiento de asignaciones + visibilidad + KPIs.
4. Sprint 4: hardening, regresion E2E y limpieza documental final.

---

## Diagrama de Dependencias entre Fases

```
F0 ──► F1 ──► F2 ──► F3 ──► F4 ──► F5
 │      │
 │      └── (F1.4 /catalog/workflow) requerido por F2.1
 │
 └── (F0.2 projectId) requerido por F1.5, F3.1
```

F0 y F1 son requisitos estrictos para todas las fases posteriores.

---

## Estimación de Esfuerzo

| Fase | Backend | Mobile | Desktop | Total |
|------|---------|--------|---------|-------|
| F0 | 0.5 día | 1 día | 1 día | 2.5 días |
| F1 | 1 día | 2 días | 1 día | 4 días |
| F2 | 2 días | 0.5 día | 1 día | 3.5 días |
| F3 | 1 día | 4 días | 0.5 día | 5.5 días |
| F4 | 1 día | 1.5 días | 1 día | 3.5 días |
| F5 | 1 día | 2 días | 1.5 días | 4.5 días |
| **Total** | **6.5 días** | **11 días** | **6 días** | **~23 días** |
