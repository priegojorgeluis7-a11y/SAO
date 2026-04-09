# SAO — Sync Architecture
**Version:** 2.0.0 | **Fecha:** 2026-03-24

## Objetivo

Definir el contrato tecnico de sincronizacion para actividades, eventos y evidencias, alineado con el flujo canonico del sistema.

Documento relacionado:

- `docs/WORKFLOW.md`
- `docs/PLAN_MEJORA_FLUJO_2026-03-24.md`

---

## 1. Principios de sync

1. Offline-first: toda captura valida se conserva localmente antes de cualquier llamada de red.
2. Idempotencia por UUID: push repetidos no deben duplicar registros.
3. Consistencia incremental: pull por cursor/version para evitar full refresh costoso.
4. Errores accionables: cada fallo debe indicar si se reintenta solo o requiere accion humana.
5. Visibilidad estable: una actividad no debe perderse por desalineacion de version o assignee.

---

## 2. Flujo de sincronizacion end-to-end

## 2.1 Vista general

```
MOBILE (Drift)                           BACKEND (Source of Truth)
-----------------                        -------------------------
Activity/Wizard
   -> SyncQueue (UPSERT/DELETE)
   -> push /api/v1/sync/push ---------------------------->
   <- per-item result (CREATED/UPDATED/UNCHANGED/CONFLICT)

Metadata cursor local
   -> pull /api/v1/sync/pull ---------------------------->
   <- activities/events + current_version + pagination

PendingUploads
   -> /api/v1/evidences/upload-init
   -> PUT signed URL
   -> /api/v1/evidences/upload-complete
```

## 2.2 Orden recomendado del ciclo

1. push de actividades y eventos pendientes
2. pull incremental por cursor
3. sync de uploads pendientes
4. actualizacion de metadata de sync (version/cursor/last_sync)

---

## 3. Modelo de estados de sync

Para UX y observabilidad se recomienda converger a estos estados funcionales:

- `LOCAL_ONLY`
- `READY_TO_SYNC`
- `SYNC_IN_PROGRESS`
- `SYNCED`
- `SYNC_ERROR`

Nota: las tablas locales pueden conservar estados tecnicos internos (`PENDING`, `DONE`, `ERROR`) siempre que la UI exponga el modelo funcional.

---

## 4. Push (mobile -> backend)

## 4.1 Contrato

Endpoint:

- `POST /api/v1/sync/push`

Requisitos:

1. Batch por proyecto.
2. Idempotencia por `uuid`.
3. Respuesta por item con estado y version resultante.
4. Manejo explicito de conflictos.

Estados por item esperados:

- `CREATED`
- `UPDATED`
- `UNCHANGED`
- `CONFLICT`
- `ERROR` (fallo no recuperable de validacion/permiso)

## 4.2 Reglas de versionado

1. Si la version cliente es compatible con servidor: aplicar update.
2. Si la version cliente es menor: marcar conflicto.
3. Toda mutacion relevante debe incrementar version del servidor.

---

## 5. Pull (backend -> mobile)

## 5.1 Contrato

Endpoint:

- `POST /api/v1/sync/pull`

Parametros esperados:

- `project_id`
- cursor de version (y cursor secundario cuando aplique)
- `limit`

Respuesta esperada:

- items actualizados desde cursor
- `current_version`
- indicador de paginacion (`has_more` o equivalente)

## 5.2 Regla de consistencia

El cliente no debe avanzar cursor local hasta aplicar en Drift todos los cambios del bloque actual.

---

## 6. Evidencias (upload en 3 pasos)

1. `POST /api/v1/evidences/upload-init`
2. `PUT signed_url` a storage
3. `POST /api/v1/evidences/upload-complete`

Reglas:

1. `upload-init` valida tipo y tamano permitido.
2. Reintentos deben respetar expiracion de signed URL.
3. Si la URL expira, reiniciar desde `upload-init`.

---

## 7. Manejo de conflictos

El conflicto es una condicion funcional del flujo, no solo un error tecnico.

Politica recomendada:

1. Primer conflicto: reintento controlado si existe estrategia segura (`force_override`) definida por negocio.
2. Persistencia de conflicto: marcar `SYNC_ERROR` con accion sugerida.
3. Exponer al usuario opcion de resolver: usar version local o adoptar version servidor.

Campos minimos de respuesta para conflicto:

- `code`: `CONFLICT`
- `server_version`
- `client_version`
- `retryable`
- `suggested_action`

---

## 8. Errores tipificados

Toda respuesta de error de sync debe incluir al menos:

- `code`
- `message`
- `retryable` (true/false)
- `suggested_action`

Categorias recomendadas:

- `NETWORK_UNAVAILABLE`
- `AUTH_EXPIRED`
- `PERMISSION_DENIED`
- `VALIDATION_FAILED`
- `CONFLICT`
- `CATALOG_MISMATCH`
- `PAYLOAD_INVALID`

---

## 9. Auto-sync

Trigger recomendados:

1. cambio offline -> online
2. timer periodico
3. accion manual desde Sync Center

Orden recomendado por corrida:

1. push pendientes
2. pull incremental
3. upload evidencias
4. refresh metricas de sync

---

## 10. Integracion con asignaciones y visibilidad

Para evitar actividades invisibles despues de sync:

1. asignaciones deben actualizar version de sync del registro afectado
2. responsable efectivo de actividad debe persistirse de forma explicita
3. cancelaciones deben usar semantica terminal clara (estado o soft-delete)

---

## 11. Metricas operativas de sync

Sync Center debe mostrar como minimo:

1. ultimo sync exitoso
2. pendientes por enviar
3. items en progreso
4. errores por categoria
5. conflictos activos
6. uploads pendientes

KPIs recomendados de proceso:

1. tiempo captura -> sync exitosa
2. tasa de reintentos
3. tasa de conflicto
4. tasa de error no recuperable

---

## 12. Pendientes y roadmap

El roadmap de endurecimiento de sync y flujo se mantiene en:

- `docs/PLAN_MEJORA_FLUJO_2026-03-24.md`
- `docs/BACKLOG_MEJORA_FLUJO_2026-03-24.md`
