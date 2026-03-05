# SAO — Plan de Implementación al 100% (Modo Local)
**Versión:** 1.0
**Fecha:** 2026-03-04
**Alcance:** Completar todos los componentes para operación 100% local; sin dependencias de GCS, Cloud SQL ni Cloud Run. Migración a servidores reales es un paso posterior independiente.

---

## Estado de partida (post-auditoría 2026-03-04)

| Componente | % Antes | % Hoy | Bloqueador principal |
|---|---|---|---|
| Backend tests | ~47% pasando | ✅ 93/93 | Fix conftest StaticPool (CERRADO) |
| Backend endpoints | 95% | 95% | `PATCH /flags` + local storage |
| App Móvil | 96% | 96% | Lista de eventos + URL local |
| Desktop Admin | 68% | 68% | Editor catálogo + Pantalla eventos + Conflictos |
| Infraestructura local | — | 0% | GCS → disco; run configs Flutter |

---

## Fases del Plan

```
L0 (Infraestructura local) ─┐
                             ├──► L1 (Backend) ──► L2 (Mobile) ──► L3 (Desktop)
                             └──────────────────────────────────────────────────► L4 (QA + E2E)
```

---

## L0 — Infraestructura Local (Prerequisito de todo)

**Objetivo:** El stack corre 100% local sin cuenta GCP. Un `README` de 3 comandos arranca todo.
**Esfuerzo estimado:** 1 día

### L0.1 — Local file storage (reemplazar GCS)

**Problema:** `EvidenceService.__init__` crea `storage.Client()` de GCS; falla sin credenciales.

**Archivos afectados:**
- `backend/app/services/evidence_service.py`
- `backend/app/core/config.py`

**Solución:**
1. Agregar `EVIDENCE_STORAGE_BACKEND = os.getenv("EVIDENCE_STORAGE_BACKEND", "gcs")` en `config.py`.
2. En `EvidenceService.__init__`:
   ```python
   if settings.EVIDENCE_STORAGE_BACKEND == "local":
       self.storage_client = None  # LocalStorageAdapter
   else:
       self.storage_client = storage.Client()
   ```
3. Crear `LocalEvidenceAdapter` que:
   - Guarda archivos en `./uploads/{activity_id}/evidences/`.
   - `upload_init` devuelve URL `http://localhost:8000/uploads/...` en lugar de presigned GCS URL.
   - `download_url` devuelve la misma URL local.
4. Agregar endpoint `GET /uploads/{path:path}` (solo en `ENV=development`) que sirve el archivo del disco.

**Gate:** `POST /evidences/upload-init` retorna 200 con `upload_url = "http://localhost:8000/uploads/..."`.

---

### L0.2 — Run configs Flutter (local)

**Problema:** URL del backend hardcoded en `app_config.dart` (mobile) y requiere `--dart-define` en desktop.

**Archivos afectados:**
- `frontend_flutter/sao_windows/lib/core/config/app_config.dart`
- `desktop_flutter/sao_desktop/lib/core/config/data_mode.dart`
- `.vscode/launch.json` (crear)

**Solución:**
1. Confirmar que mobile lee `String.fromEnvironment('SAO_API_BASE', defaultValue: 'http://localhost:8000/api/v1')`.
2. Crear `.vscode/launch.json` con 3 configuraciones:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Mobile — Local",
      "type": "dart",
      "request": "launch",
      "program": "frontend_flutter/sao_windows/lib/main.dart",
      "args": ["--dart-define=SAO_API_BASE=http://localhost:8000/api/v1"]
    },
    {
      "name": "Desktop — Local",
      "type": "dart",
      "request": "launch",
      "program": "desktop_flutter/sao_desktop/lib/main.dart",
      "args": ["--dart-define=SAO_BACKEND_URL=http://localhost:8000"]
    },
    {
      "name": "Desktop — Producción",
      "type": "dart",
      "request": "launch",
      "program": "desktop_flutter/sao_desktop/lib/main.dart",
      "args": ["--dart-define=SAO_BACKEND_URL=https://sao-api-fjzra25vya-uc.a.run.app"]
    }
  ]
}
```

**Gate:** `flutter run` sin argumentos adicionales conecta a `localhost:8000`.

---

### L0.3 — Script único de inicio local

**Archivo:** `backend/scripts/start_local.ps1` (verificar y completar el existente `start_local_sqlite.ps1`)

**Solución:** Script que en secuencia:
```powershell
# 1. Set env vars locales
$env:DATABASE_URL       = "sqlite:///./sao_local.db"
$env:JWT_SECRET         = "dev-secret-change-in-prod"
$env:GCS_BUCKET         = "local"
$env:EVIDENCE_STORAGE_BACKEND = "local"
$env:CORS_ORIGINS       = "http://localhost:8000,http://localhost:3000"
$env:ENV                = "development"
$env:SIGNUP_INVITE_CODE = "SAO2026"
$env:ADMIN_INVITE_CODE  = "ADMIN2026"

# 2. Migraciones
alembic upgrade head

# 3. Seeds (idempotente)
python -m app.seeds.initial_data

# 4. Servidor
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Gate:** `curl http://localhost:8000/api/v1/catalog/bundle?project_id=TMQ` retorna JSON con bundle.

---

## L1 — Backend: Completar al 100%

**Esfuerzo estimado:** 0.5 día

### L1.1 — `PATCH /activities/{uuid}/flags`

**Problema:** El endpoint nunca fue implementado (identificado en auditoría F2.5). Desktop filtra actividades con `description.contains('gps')` porque no hay campo estructurado.

**Archivos afectados:**
- `backend/app/api/v1/activities.py`
- `backend/app/schemas/activity.py`

**Solución:**

Schema (`schemas/activity.py`):
```python
class ActivityFlagsUpdate(BaseModel):
    gps_mismatch: bool | None = None
    catalog_changed: bool | None = None
```

Endpoint (`api/v1/activities.py`):
```python
@router.patch("/{uuid}/flags", response_model=ActivityDTO)
async def patch_activity_flags(
    uuid: str,
    flags: ActivityFlagsUpdate,
    db: Session = Depends(get_db),
    authenticated_user: User = Depends(get_current_user),
):
    service = ActivityService(db)
    activity = service.get_activity_by_uuid(uuid)
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    if flags.gps_mismatch is not None:
        activity.gps_mismatch = flags.gps_mismatch
    if flags.catalog_changed is not None:
        activity.catalog_changed = flags.catalog_changed
    db.commit()
    db.refresh(activity)
    return service.to_dto(activity)
```

**Test a agregar:** `tests/test_activities.py::test_patch_flags_updates_gps_mismatch`

**Gate:** `PATCH /api/v1/activities/{uuid}/flags` retorna 200 con flags actualizados.

---

### L1.2 — Test de `PATCH /flags`

Agregar en `backend/tests/test_activities.py`:
```python
def test_patch_activity_flags(client, auth_headers, ...):
    # crear actividad → PATCH flags → verificar ActivityDTO.flags
```

**Gate:** `pytest backend/tests/test_activities.py -q` → todos pasan (sin regresión).

---

## L2 — App Móvil: Completar al 100%

**Esfuerzo estimado:** 1 día

### L2.1 — Lista de eventos del proyecto

**Problema:** Solo existe `ReportEventSheet` (FAB para crear). No hay pantalla para ver eventos existentes del proyecto.

**Archivos a crear/modificar:**
- `lib/features/events/ui/events_list_page.dart` ← **nuevo**
- `lib/core/routing/app_router.dart` — agregar ruta `/events`
- `lib/features/home/home_page.dart` — agregar acceso a la lista

**Diseño de la pantalla (`events_list_page.dart`):**
```dart
// - AppBar: "Eventos del Proyecto"
// - ListView de EventDTO con:
//     • Chip de severidad (color de SaoColors según severity)
//     • Tipo de evento + descripción truncada
//     • Fecha relativa ("hace 2 horas")
//     • Indicador de sync (local/synced)
// - FAB: abrir ReportEventSheet existente
// - Pull-to-refresh: llama eventsProvider.refresh()
// - Estado vacío: "No hay eventos registrados aún"
```

**Providers a usar (ya existen):**
- `eventsLocalRepositoryProvider` — datos locales Drift
- `eventsApiRepositoryProvider` — pull desde API

**Ruta a agregar en `app_router.dart`:**
```dart
GoRoute(
  path: '/events',
  builder: (_, __) => const EventsListPage(),
),
```

**Acceso desde home:** Agregar ítem en `NavigationRail` o botón en `HomePage`.

**Gate:** Usuario puede ver lista de eventos y crear nuevo desde la misma pantalla.

---

### L2.2 — Verificar URL local configurable

Confirmar que `app_config.dart` lee de `String.fromEnvironment`. Si está hardcoded, actualizar.

**Gate:** `--dart-define=SAO_API_BASE=http://10.0.2.2:8000/api/v1` conecta mobile al backend local (emulador Android usa `10.0.2.2`; Windows usa `localhost`).

---

## L3 — Desktop Admin: Completar al 100%

**Esfuerzo estimado:** 5 días (L3.1 es el mayor)

### L3.1 — Editor de Catálogo UI [MAYOR ESFUERZO]

**Contexto:** El backend tiene 10+ endpoints de editor (`catalog_editor_service.py`, `catalog_editor.py`). La `CatalogsPage` desktop tiene vista de datos y reordenamiento pero **sin dialogs de crear/editar/eliminar** funcionales.

**Archivos a crear/modificar:**
- `lib/features/catalogs/catalogs_page.dart` — implementar `_onCreatePressed()` y callbacks de edición/borrado
- `lib/features/catalogs/widgets/activity_edit_dialog.dart` ← **nuevo**
- `lib/features/catalogs/widgets/subcategory_edit_dialog.dart` ← **nuevo**
- `lib/features/catalogs/widgets/purpose_edit_dialog.dart` ← **nuevo**
- `lib/features/catalogs/widgets/topic_edit_dialog.dart` ← **nuevo**
- `lib/features/catalogs/catalogs_controller.dart` — agregar `createItem()`, `updateItem()`, `deleteItem()`
- `lib/data/repositories/catalog_repository.dart` — agregar llamadas a API editor

**API del backend a consumir:**
```
POST   /api/v1/catalog/editor/activities
PATCH  /api/v1/catalog/editor/activities/{id}
DELETE /api/v1/catalog/editor/activities/{id}
POST   /api/v1/catalog/editor/subcategories
PATCH  /api/v1/catalog/editor/subcategories/{id}
DELETE /api/v1/catalog/editor/subcategories/{id}
[…similar para purposes, topics, results, assistants]
POST   /api/v1/catalog/validate       ← antes de publicar
POST   /api/v1/catalog/publish
POST   /api/v1/catalog/rollback
```

**Dialog de actividad (ejemplo):**
```dart
// ActivityEditDialog:
// - Campo: ID (auto-generado o editable solo en creación)
// - Campo: Label (texto)
// - Campo: Icon (selector de íconos predefinidos)
// - Campo: Default risk (dropdown: LOW/MEDIUM/HIGH/CRITICAL)
// - Toggle: Requires GPS
// - Toggle: Requires evidence
// - Número: Min photos (0-10)
// - Botón Guardar → PATCH/POST API → controller.refresh()
```

**Flujo de publicación (ya tiene botones en CatalogsHeader):**
```
onValidate → POST /catalog/validate → mostrar resultado
onPublish  → POST /catalog/publish  → SnackBar éxito
onRollback → POST /catalog/rollback → confirmación previa
```

**Gate:** Admin puede crear, editar y eliminar una actividad desde la UI; publicar el catálogo; ver cambios reflejados en mobile tras sync.

---

### L3.2 — Pantalla de Eventos Desktop

**Problema:** No existe ningún archivo ni ruta para eventos en el desktop.

**Archivos a crear/modificar:**
- `lib/features/events/events_page.dart` ← **nuevo**
- `lib/app/shell.dart` — agregar ítem `Eventos` al `NavigationRail`

**Diseño de la pantalla:**
```dart
// EventsPage:
// - Tabla/lista de eventos del proyecto (GET /events?project_id=X)
// - Columnas: Tipo | Severidad | Descripción | PK | Fecha | Reportado por
// - Filtros: por severidad (LOW/MEDIUM/HIGH/CRITICAL), por fecha
// - Chip de estado de resolución (resolved_at != null → "Resuelto")
// - Acción: marcar como resuelto (PATCH /events/{uuid} con resolved_at)
// - Sin FAB de creación (coordinador no crea eventos, solo los gestiona)
```

**Gate:** Coordinador puede ver lista de eventos del proyecto y marcar uno como resuelto.

---

### L3.3 — Resolución de Conflictos UI

**Problema:** `ReviewDecisionOutbox` maneja reintentos de conexión pero los conflictos de sync de actividades no tienen UI de resolución.

**Archivos a modificar:**
- `lib/features/operations/validation_page.dart` — detectar actividades con status `CONFLICT`
- `lib/features/operations/widgets/conflict_resolution_dialog.dart` ← **nuevo**
- `lib/data/repositories/activity_repository.dart` — agregar soporte `force_override`

**Diseño del dialog:**
```dart
// ConflictResolutionDialog:
// - Título: "Conflicto de sincronización"
// - Descripción: "Esta actividad fue modificada en el servidor. ¿Qué versión deseas conservar?"
// - Panel izquierdo: "Versión local" — muestra campos clave
// - Panel derecho: "Versión del servidor" — muestra campos clave
// - Botón "Usar versión local" → POST /sync/push con force_override: true
// - Botón "Usar versión del servidor" → pull activo de esta actividad
```

**Gate:** Actividades con status `CONFLICT` en la cola muestran dialog con opciones de resolución.

---

### L3.4 — Color hardcodes menores

**3 archivos con colores hardcoded (del audit):**

| Archivo | Color actual | Reemplazar por |
|---|---|---|
| `lib/features/admin/admin_shell.dart:59` | `Color(0xFFE2E8F0)` | `SaoColors.border` |
| `lib/features/auth/app_login_page.dart:131,138,144` | `Colors.red.shade*` | `SaoColors.error` |
| `lib/features/users/users_page.dart:117` | `Colors.red` | `SaoColors.error` |

**Gate:** `grep -r "Color(0xFF\|Colors\.red" desktop_flutter/sao_desktop/lib/` → 0 resultados en `features/`.

---

### L3.5 — Tests unitarios desktop (ampliar cobertura)

**Estado actual:** Solo auth/sesión cubiertos (5 archivos, 444 LOC).

**Tests a agregar:**

| Archivo nuevo | Qué cubre |
|---|---|
| `test/features/catalogs/catalogs_controller_test.dart` | create/edit/delete de ítems; publish/rollback |
| `test/features/operations/review_queue_test.dart` | filtros por status, GPS, catalog_changed |
| `test/features/reports/reports_page_test.dart` | carga de proyectos dinámicos; no TMQ hardcoded |
| `test/features/events/events_page_test.dart` | lista vacía; marcar resuelto |

**Gate:** `flutter test desktop_flutter/sao_desktop/` → 30+ tests pasando.

---

## L4 — QA y Test E2E Local

**Esfuerzo estimado:** 1 día

### L4.1 — Script E2E local

Crear `backend/scripts/e2e_local.py` que ejecuta:

```
1. Login como OPERATIVO → obtener token
2. Crear actividad (POST /activities)
3. Crear evidencia (POST /evidences/upload-init → upload → complete)
4. Push sync (POST /sync/push)
5. Login como COORD → obtener token
6. Ver cola de revisión (GET /review/queue) → actividad aparece
7. Aprobar actividad (POST /review/activity/{uuid}/decision)
8. Login como OPERATIVO de nuevo
9. Pull sync (POST /sync/pull) → actividad muestra status APROBADO
10. Verificar eventos: crear evento (PUT /events/{uuid}) → listar (GET /events)
```

**Gate:** Script corre con salida `✅ E2E PASSED` sin errores.

---

### L4.2 — Checklist de regresión manual

Antes de marcar Desktop al 100%, verificar manualmente:

```
□ Login con credenciales locales
□ Ver cola de revisión → actividades aparecen
□ Aprobar / Rechazar una actividad → mobile ve resultado tras pull
□ Crear actividad en catálogo editor → bundle se actualiza
□ Publicar catálogo → versión incrementa
□ Ver lista de eventos → filtrar por severidad
□ Resolver un conflicto → actividad desaparece de cola conflictos
□ Admin: crear usuario → usuario puede loguearse
□ Reports: proyectos cargados dinámicamente (no TMQ hardcoded)
```

---

## Resumen de Esfuerzo

| Fase | Componente | Tareas | Días estimados |
|---|---|---|---|
| **L0** | Infraestructura local | L0.1 GCS local · L0.2 Run configs · L0.3 Script inicio | **1 día** |
| **L1** | Backend | L1.1 PATCH /flags · L1.2 Test | **0.5 día** |
| **L2** | Mobile | L2.1 Lista eventos · L2.2 URL local | **1 día** |
| **L3** | Desktop | L3.1 Editor catálogo · L3.2 Eventos · L3.3 Conflictos · L3.4 Colors · L3.5 Tests | **5 días** |
| **L4** | QA E2E | L4.1 Script E2E · L4.2 Checklist manual | **1 día** |
| **TOTAL** | | | **~8.5 días** |

---

## Roadmap Visual

```
Día 1        Día 2        Día 3-7              Día 8        Día 9
  │            │             │                    │            │
 L0.1         L1.1          L3.1                L3.2         L4.1
 L0.2         L1.2          L3.2 (paralelo)     L3.3         L4.2
 L0.3         L2.1          L3.3 (paralelo)     L3.4
              L2.2          L3.5                L3.5
                │
             Backend 100% + Mobile 100%
                                               Desktop 100%   QA 100%
```

---

## Prioridad Sugerida de Implementación

1. **L0.1 primero** — sin local storage, evidencias bloquean todo.
2. **L0.2 + L0.3** — un solo día para tener el stack local corriendo.
3. **L1 + L2 en paralelo** — son independientes y rápidos (1.5 días).
4. **L3.1 (editor catálogo)** — el mayor esfuerzo; empezar pronto.
5. **L3.2 + L3.3 en paralelo** con L3.1 si hay más de una persona.
6. **L4 al final** — solo cuando todo lo anterior está verde.

---

## Gates de Aceptación Final

| Componente | Criterio de 100% |
|---|---|
| Backend | `pytest backend/tests -q` → 95+ pasando; `PATCH /flags` existe; GCS local funciona |
| Mobile | Lista de eventos muestra datos; wizard conecta a `localhost` sin recompilar |
| Desktop | Editor catálogo crea/edita/elimina; pantalla eventos existe; conflictos tienen dialog |
| QA | Script E2E local pasa; checklist manual completo sin items ❌ |

---

## Notas de Migración a Producción (posterior)

Cuando se migre de local a servidores reales, los únicos cambios son:

1. **Backend:** Cambiar `EVIDENCE_STORAGE_BACKEND=gcs` y proveer credenciales GCP.
2. **Mobile:** `--dart-define=SAO_API_BASE=https://sao-api-fjzra25vya-uc.a.run.app/api/v1`
3. **Desktop:** `--dart-define=SAO_BACKEND_URL=https://sao-api-fjzra25vya-uc.a.run.app`
4. **DB:** `DATABASE_URL=postgresql://...` (Cloud SQL o cualquier Postgres).

El código de aplicación **no cambia**; solo variables de entorno y dart-defines.
