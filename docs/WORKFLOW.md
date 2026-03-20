# SAO — Workflow de Actividades
**Versión:** 1.0.0 | **Fecha:** 2026-03-04

## Actualizacion 2026-03-10

- El flujo base operativo -> review -> pull fue validado en produccion controlada con resultado PASS.
- `POST /review/activity/{id}/decision` ya opera en modo Firestore para approve/reject/approve_exception.
- Evidencia del flujo validado:
     - push status: `CREATED`
     - estado final en pull: `COMPLETADA`

---

## 1. Estados y Transiciones

### 1.1 Diagrama de Estados

```
                    ┌─────────┐
                    │ BORRADOR │  (creado offline, no enviado)
                    └────┬────┘
                         │ operativo envía
                         ▼
                    ┌─────────┐
                    │  NUEVO  │  (en servidor, pendiente revisión)
                    └────┬────┘
                         │ coordinador inicia revisión
                         ▼
                 ┌───────────────┐
           ┌────►│  EN_REVISION  │◄────────────────┐
           │     └───────┬───────┘                 │
           │             │                         │
           │    ┌────────┼──────────┐              │
           │    ▼        ▼          ▼              │
           │ APROBADO  RECHAZADO  REQUIERE_CAMBIOS ─┘
           │    │        (✗)       operativo corrige
           │    │
           │    ▼
           │ SINCRONIZADO  (terminal exitoso)
           │
           │ OFFLINE → SINCRONIZADO | CONFLICTO
           │               CONFLICTO → EN_REVISION
```

### 1.2 Estados Definidos

| Estado | Código Backend | Código Mobile | Descripción |
|--------|---------------|---------------|-------------|
| Borrador | `PENDIENTE` | `DRAFT` | Creada localmente, no enviada |
| Nuevo | `EN_CURSO` | `READY_TO_SYNC` | En servidor, en espera de revisión |
| En revisión | `REVISION_PENDIENTE` | `SYNCED` | Coordinador la está revisando |
| Requiere cambios | — | — | Coordinador solicitó correcciones |
| Aprobado | `COMPLETADA` | `SYNCED` | Aprobada por coordinador |
| Rechazado | — | — | Rechazada (terminal) |
| Sincronizado | — | `SYNCED` | Confirmada en servidor |
| Offline | — | `DRAFT` | Pendiente de sync (sin red) |
| Conflicto | — | `ERROR` | Conflicto detectado en push |

> **Deuda:** Los estados del backend (`ExecutionState`) y del mobile (`SyncStatus`) no están completamente alineados. Ver AUDIT_REPORT.md §3.

### 1.3 Transiciones y Permisos

| Desde | Hacia | Condición | Rol mínimo | Endpoint |
|-------|-------|-----------|------------|---------|
| `borrador` | `nuevo` | Formulario completo, al menos 1 evidencia | OPERATIVO | Push sync |
| `nuevo` | `en_revision` | Coordinador inicia review | COORD | Implícito en review queue |
| `en_revision` | `aprobado` | Checklist OK, sin observaciones | COORD | `POST /review/activity/{id}/decision` |
| `en_revision` | `rechazado` | Falla crítica no subsanable | COORD | `POST /review/activity/{id}/decision` |
| `en_revision` | `requiere_cambios` | Observaciones pendientes | COORD | `POST /review/activity/{id}/decision` |
| `requiere_cambios` | `en_revision` | Operativo corrige y reenvía | OPERATIVO | Push sync |
| `requiere_cambios` | `rechazado` | Incumplimiento persistente | COORD | `POST /review/activity/{id}/decision` |
| `aprobado` | `sincronizado` | Confirmación automática del servidor | SYSTEM | Automático |
| `conflicto` | `en_revision` | Resolución manual | COORD | Pendiente UI |
| Cualquier estado | `APPROVE_EXCEPTION` | Circunstancia excepcional | **ADMIN** | `POST /review/activity/{id}/decision` |

Nota operativa 2026-03-10: la transición de decisión ya no depende de SQL en modo `DATA_BACKEND=firestore`.

---

## 2. Checklist de Actividad (por tipo)

Los checklists son **catalog-driven**. Actualmente definidos en `effective.rules` del bundle:

| Tipo | Checklist obligatorio |
|------|----------------------|
| CAM | Mínimo 1 foto, punto GPS |
| REU | Lista de asistentes, acta |
| ASP | Acta firmada, quórum documentado |
| CIN | Intérprete identificado, minutas |
| SOC | Material de difusión referenciado |
| AIN | Institución participante registrada |

> **FALTA:** Backend no valida checklists por tipo de actividad al momento de revisión. Actualmente el coordinador lo verifica manualmente.

---

## 3. Cola de Revisión (Desktop)

### 3.1 Tabs de la cola

| Tab | Filtro | Fuente de datos |
|-----|--------|-----------------|
| PENDIENTE | `status == PENDING_REVIEW` | `GET /review/queue` |
| REQUIERE CAMBIOS | `status == CONFLICT` o flag `catalog_changed` | `GET /review/queue` + flags |
| GPS | Flag `gps_mismatch == true` | `GET /review/queue` + flags |
| RECHAZADO | `status == REJECTED` | `GET /review/queue` |
| TODOS | Sin filtro | `GET /review/queue` |

> **Deuda actual:** GPS y REQUIERE CAMBIOS se detectan por `description.contains('gps')` (text matching). Ver AUDIT_REPORT.md §1.4. **Fix:** agregar campos estructurados `flags.gps_mismatch` y `flags.catalog_changed` en ActivityDTO.

### 3.2 Pantalla de detalle (ValidationPage)

Paneles:
- **Evidence Gallery** — fotos con captions, GPS stamp
- **Activity Details** — datos del formulario dinámico
- **Minimap** — visualización GPS de la actividad
- **Review Actions** — botones Aprobar / Rechazar / Solicitar cambios

### 3.3 Reject Playbook

`GET /review/reject-playbook` devuelve:

| Código | Descripción | Severidad |
|--------|-------------|-----------|
| `PHOTO_BLUR` | Foto borrosa o ilegible | MED |
| `GPS_MISMATCH` | GPS no coincide con PKs declarados | HIGH |
| `MISSING_INFO` | Información obligatoria ausente | MED |

> **Deuda:** razones hardcoded en backend. Mover a tabla `reject_reasons` en BD.

---

## 4. Trazabilidad

### 4.1 Audit Log (Backend)

Cada decisión de workflow genera registro en `audit_logs`:

| Acción | Cuando |
|--------|--------|
| `REVIEW_APPROVE` | Actividad aprobada |
| `REVIEW_REJECT` | Actividad rechazada |
| `REVIEW_APPROVE_EXCEPTION` | Aprobación excepcional (ADMIN) |
| `REVIEW_EVIDENCE_VALIDATE` | Evidencia validada individualmente |
| `REVIEW_EVIDENCE_PATCH` | Evidencia modificada (caption, etc.) |
| `OBSERVATION_CREATED` | Observación creada sobre actividad |
| `OBSERVATION_RESOLVED` | Observación resuelta |

### 4.2 Activity Log (Mobile — local)

`ActivityLog` table en Drift:

| EventType | Cuando |
|-----------|--------|
| `CREATED` | Actividad creada |
| `EDITED` | Formulario editado |
| `EVIDENCE_ADDED` | Foto/evidencia agregada |
| `SUBMITTED` | Enviada a revisión |
| `SYNC_OK` | Sincronizada con servidor |

> **FALTA:** Historial local no se expone al coordinador (no existe `GET /api/v1/activities/{uuid}/timeline`).

---

## 5. Observaciones (módulo complementario)

Las observaciones son notas que el coordinador adjunta a una actividad durante revisión.

**Endpoint:** `POST /observations` (⚠️ falta prefijo `/api/v1` — ver AUDIT_REPORT.md §4)

**Estados:** pendiente → resolved

**Workflow:**
1. Coordinador crea observación con `severity`, `message`, `due_date`, `tags_json`.
2. Operativo resuelve con `POST /mobile/observations/{id}/resolve`.
3. Sistema registra `resolved_at`.

> **Deuda:** Observaciones no tienen pantalla en mobile ni en desktop actualmente.

---

## 6. Eventos (módulo separado de actividades)

Los eventos son incidentes operativos (no actividades planificadas).

**Severidad:** LOW / MEDIUM / HIGH / CRITICAL

**Workflow actual:** Crear → (opcional) Resolver (`resolved_at != null`)

> **FALTA:** Eventos no tienen cola de revisión. No está claro si deben pasar por el mismo workflow. **Assumption:** eventos con severidad HIGH/CRITICAL deberían tener revisión obligatoria.
