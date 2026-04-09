# SAO — Workflow de Actividades
**Version:** 2.0.0 | **Fecha:** 2026-03-24

## Objetivo

Definir el contrato canonico del flujo operativo de actividades para backend, mobile y desktop.

Este documento actualiza la semantica del flujo despues del cierre base F0-F5 y se alinea con:

- `STATUS.md`
- `IMPLEMENTATION_PLAN.md` (addendum 2026-03-24)
- `docs/PLAN_MEJORA_FLUJO_2026-03-24.md`

---

## 1. Modelo de estado canonico

Una actividad se interpreta en tres dimensiones independientes.

## 1.1 Estado operativo

Describe el avance del trabajo en campo:

- `PENDIENTE`
- `EN_CURSO`
- `POR_COMPLETAR`
- `BLOQUEADA`
- `CANCELADA`

## 1.2 Estado de sincronizacion

Describe la situacion de envio y consistencia con backend:

- `LOCAL_ONLY`
- `READY_TO_SYNC`
- `SYNC_IN_PROGRESS`
- `SYNCED`
- `SYNC_ERROR`

## 1.3 Estado de revision

Describe el ciclo de coordinacion:

- `NOT_APPLICABLE`
- `PENDING_REVIEW`
- `CHANGES_REQUIRED`
- `APPROVED`
- `REJECTED`

## 1.4 Regla de oro

La UI debe consumir una proyeccion de flujo y evitar heuristicas locales que mezclen estados crudos de tablas distintas.

---

## 2. Ciclo de vida funcional

## 2.1 Flujo base

1. La actividad entra en `PENDIENTE`.
2. El operativo inicia y pasa a `EN_CURSO`.
3. Al terminar ejecucion pasa a `POR_COMPLETAR`.
4. El wizard consolida captura y evidencia.
5. El item queda `READY_TO_SYNC`.
6. Sync actualiza a `SYNCED` o `SYNC_ERROR`.
7. Si requiere revision, entra a `PENDING_REVIEW`.
8. Coordinacion decide `APPROVED`, `CHANGES_REQUIRED` o `REJECTED`.
9. Si hay `CHANGES_REQUIRED`, el operativo corrige y reenvia.

## 2.2 Principio de visibilidad

Una actividad no debe desaparecer por cambios de estado interno. Puede cambiar de bandeja, pero debe permanecer visible segun su siguiente accion.

---

## 3. Transiciones clave

| Evento | Estado operativo | Estado sync | Estado revision | Siguiente accion esperada |
|-------|-------------------|-------------|-----------------|---------------------------|
| Asignacion recibida | `PENDIENTE` | `SYNCED` o `LOCAL_ONLY` | `NOT_APPLICABLE` | Iniciar actividad |
| Inicio de actividad | `EN_CURSO` | sin cambio | `NOT_APPLICABLE` | Ejecutar trabajo |
| Fin de ejecucion | `POR_COMPLETAR` | sin cambio | `NOT_APPLICABLE` | Completar wizard |
| Guardado valido de wizard | `POR_COMPLETAR` | `READY_TO_SYNC` | `NOT_APPLICABLE` | Enviar/sincronizar |
| Push/Pull exitoso | sin cambio | `SYNCED` | `PENDING_REVIEW` o `NOT_APPLICABLE` | Esperar decision o continuar |
| Error de sync | sin cambio | `SYNC_ERROR` | sin cambio | Reintentar o resolver conflicto |
| Decision APPROVED | sin cambio | `SYNCED` | `APPROVED` | Cierre administrativo |
| Decision CHANGES_REQUIRED | `POR_COMPLETAR` | `SYNCED` | `CHANGES_REQUIRED` | Corregir observaciones |
| Decision REJECTED | `CANCELADA` o terminal | `SYNCED` | `REJECTED` | Cierre con trazabilidad |

---

## 4. Roles y permisos de decision

| Accion | Rol minimo |
|-------|------------|
| Iniciar/terminar/capturar actividad | `OPERATIVO` |
| Aprobar/rechazar/solicitar cambios | `COORD` |
| `APPROVE_EXCEPTION` | `ADMIN` |

Endpoint de decision:

- `POST /api/v1/review/activity/{id}/decision`

---

## 5. Checklist y validaciones

Los checklists son catalog-driven y deben permanecer alineados con el bundle vigente (`effective.rules`).

Reglas operativas:

1. La app puede guardar parcial en wizard, pero debe informar faltantes.
2. El envio a revision debe aplicar validacion consistente entre cliente y backend.
3. La devolucion por checklist debe indicar campo/regla accionable, no solo mensaje generico.

---

## 6. Revision y observaciones

## 6.1 Cola de revision (desktop)

La cola debe usar estados y flags estructurados, no text matching sobre descripcion.

Tabs sugeridos:

- Pendiente
- Requiere cambios
- GPS
- Rechazado
- Todos

## 6.2 Observaciones estructuradas

Una observacion de revision debe incluir como minimo:

- categoria
- severidad
- campo o evidencia afectada
- accion sugerida
- fecha objetivo opcional

Endpoints base:

- `POST /api/v1/observations`
- `GET /api/v1/mobile/observations`
- `POST /api/v1/mobile/observations/{id}/resolve`

---

## 7. Trazabilidad

Toda decision y correccion relevante debe quedar auditada.

Eventos minimos esperados:

- `REVIEW_APPROVE`
- `REVIEW_REJECT`
- `REVIEW_APPROVE_EXCEPTION`
- `OBSERVATION_CREATED`
- `OBSERVATION_RESOLVED`
- eventos de sync asociados al ciclo (`SYNC_OK`, `SYNC_ERROR`, `CONFLICT_RESOLVED`)

---

## 8. Integracion con sync

El workflow depende de sync para completar el ciclo operativo-administrativo.

Regla:

`POR_COMPLETAR` no implica `APPROVED`; la aprobacion es un estado de revision posterior al intercambio con backend.

Referencia tecnica:

- `docs/SYNC.md`

---

## 9. KPIs recomendados del flujo

1. tiempo asignacion -> inicio
2. tiempo fin -> captura completa
3. tiempo captura -> sync exitosa
4. tiempo en revision
5. tasa de `CHANGES_REQUIRED` por tipo
6. tasa de `SYNC_ERROR` por causa

---

## 10. Pendientes de mejora

Los items de endurecimiento y roadmap viven en:

- `docs/PLAN_MEJORA_FLUJO_2026-03-24.md`
- `docs/BACKLOG_MEJORA_FLUJO_2026-03-24.md`

