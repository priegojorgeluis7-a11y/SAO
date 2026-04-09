# Análisis del Flujo SAO - Mejoras Operativas (2026-03-27)

## Resumen Ejecutivo

El sistema SAO ya tiene funcionalidad base cerrada (F0-F5). El siguiente paso es **endurecer el flujo operativo** para que sea observable, accionable y predecible en todos los roles. Actualmente hay fricción en:

1. **Visibilidad de actividades**: Operativos no ven sus actividades si `assigned_to_user_id` es NULL (ya corregido con fallback a `created_by_user_id`)
2. **Estados compuestos ambiguos**: Misma actividad con múltiples interpretaciones según capa (operativo, sync, review)
3. **Filtrado paralelo**: Reglas de visibilidad duplicadas entre frontend/backend
4. **Devoluciones técnicas**: Revisiones retornan con criterios poco accionables para el operativo
5. **Falta de resumen de readiness**: No es claro qué le falta a una captura antes de enviar

---

## 1. Análisis por Rol y Pantalla

### 1.1 OPERATIVO (rol: OPERATIVO)

**Permisos actuales:**
- Ver actividades
- Crear actividades  
- Editar actividades
- Ver catálogo
- Ver eventos
- Crear eventos

**Flujo actual:**
```
Home (filtrado por assignedToUserId == currentUserId)
  ↓
Selecciona actividad
  ↓
Inicia/Termina
  ↓
Wizard (4 pasos: contexto, clasificación, evidencias, confirmación)
  ↓
READY_TO_SYNC + enqueue
  ↓
Sync Center (esperando red o enviando)
  ↓
Pull → actualiza estado → vuelve a Home
```

**Problemas actuales:**

| Problema | Síntoma | Severidad | Status |
|----------|---------|-----------|--------|
| Visibilidad de asignación | Actividades desaparecen si `assigned_to_user_id` NULL | 🔴 CRÍTICA | ✅ CORREGIDO (fallback) |
| Estados confusos | "READY_TO_SYNC" no es un término operativo | 🟡 MEDIA | ⏳ PENDIENTE |
| Pérdida de avance en wizard | Cerrar app sin guardar pierde datos | 🔴 CRÍTICA | ⏳ PENDIENTE |
| Errores opacos de sync | "network error" sin acción sugerida | 🟡 MEDIA | ⏳ PENDIENTE |
| Devoluciones sin contexto | "CHANGES_REQUIRED" sin detallar qué | 🔴 CRÍTICA | ⏳ PENDIENTE |
| Sin resumen de readiness | No sé qué falta antes de guardar | 🟡 MEDIA | ⏳ PENDIENTE |

**Mejoras recomendadas (Prioridad):**

1. **P0 - Persistencia de wizard por paso** (MO-04)
   - Guardar cada respuesta del wizard en DB local
   - Permita reapertura en último paso válido
   - Cierre inesperado no pierde avance

2. **P0 - Home como bandeja de tareas** (MO-01)
   - Reemplazar "READY_TO_SYNC" por: "Por iniciar", "En curso", "Por completar", "Corregir", "Error de envío"
   - Estados operativos, no técnicos
   - Cada sección con acción clara

3. **P1 - Resumen de readiness pre-envío** (MO-06)
   - Mostrar checklist de faltantes: "Falta GPS", "Falta evidencia 1/3", "Falta clasificación"
   - Bloquear envío si no está listo y explicar por qué
   - Guía paso a paso de qué completar

4. **P1 - Devoluciones estructuradas** (MO-08)
   - "Changes required" → detallar qué campo, qué observación, acción sugerida
   - Mostrar pantalla de "Corregir" con acceso directo al campo observado
   - Histórico de iteraciones

5. **P2 - Errores tipificados con retry** (MO-07)
   - Red caída → "Sin conexión. Reintentar automático cuando haya red"
   - Servidor rechaza → "Datos incompletos. Ve a Contexto y revisa estado"
   - Permiso insuficiente → "Contacta coordinación; tu rol no puede enviar"

---

### 1.2 SUPERVISOR (rol: SUPERVISOR)

**Permisos actuales:**
- Ver actividades
- Crear actividades
- Editar actividades
- Aprobar actividades
- Rechazar actividades
- Crear eventos
- Editar eventos
- Ver eventos
- Ver reportes

**Flujo actual:**
- Home mostrando TODAS las actividades de su equipo
- Puede editar actividades de operativos
- Puede revisar y tomar decisiones (APPROVE, REJECT, CHANGES_REQUIRED)
- Ver reportes por proyecto y rango

**Problemas actuales:**

| Problema | Síntoma | Severidad |
|----------|---------|-----------|
| Filtrado confuso | Home no distingue "mías" vs "de mi equipo" | 🟡 MEDIA |
| Review sin contexto | No ve GPS crítico hasta abrir detalle | 🟡 MEDIA |
| Por qué se devuelve | Necesita copiar observación en texto libre | 🟡 MEDIA |
| Síntesis de readiness | No ve resumen de faltantes en queue | 🟡 MEDIA |

**Mejoras recomendadas:**

1. **P1 - Review queue con priorización** (DE-02)
   - Mostrar criticalidad: GPS crítico, evidencias faltantes, observaciones previas
   - Ordenar por: GPS crítico > cambios previos > nuevas > otras
   - Abrir review con checklist visible

2. **P1 - Devoluciones estructuradas** (DE-03)
   - Categorizá devolucion: "Falta dato", "GPS crítico", "Evidencia insuficiente", "Otra"
   - Severidad: menor, media, crítica
   - Observación escrita + código para acción sugerida

---

### 1.3 COORDINADOR (rol: COORD)

**Permisos actuales:**
- Ver actividades
- Crear actividades
- Editar actividades
- Aprobar actividades
- Rechazar actividades
- Crear eventos
- Editar eventos
- Ver eventos
- Ver catálogo
- Ver reportes
- Exportar reportes
- Administrar asignaciones

**Flujo actual:**
- Desktop: Review Queue listando pendientes, cambios, GPS crítico
- Decide APPROVE, REJECT, CHANGES_REQUIRED, APPROVE_EXCEPTION
- Administrativa: Asigna/reasigna actividades
- Reportes: Exporta por proyecto, rango, estado

**Problemas actuales:**

| Problema | Síntoma | Severidad |
|----------|---------|-----------|
| Queue sin resumen | No ve anticipado: faltantes, GPS, etc | 🟡 MEDIA |
| Devolucion texto libre | Observación no estructurada = confusión en mobile | 🔴 CRÍTICA |
| Dashboard volumen, no flujo | KPIs no muestran fricción del proceso | 🟡 MEDIA |
| Asignación sin versionado | Reasignar puede perder visibilidad en operativo | 🟡 MEDIA |

**Mejoras recomendadas:**

1. **P0 - Review queue consumidor de proyección canónica** (DE-01)
   - Queue muestra: operativo asignado, activity_type, título, pk, estado operativo, flags críticos
   - Colores/iconos para GPS crítico, evidencias faltantes, cambios previos
   - Ordenamiento inteligente por criticidad

2. **P0 - Devoluciones con estructura** (DE-03)
   - Formulario de decision con campos:
     - Categoría: (observación de campo, GPS crítico, falta evidencia, otra)
     - Severidad: menor/media/crítica
     - Observación texto
     - Acción sugerida codificada
   - Resultado se serializa en backend → mobile interpreta

3. **P2 - Dashboard de KPIs operativos** (DE-05)
   - En vez de: "200 aprobadas, 50 rechazadas"
   - Mostrar: "Completadas hoy 80% (80/100)", "Promedio iteraciones 1.2", "Falta GPS 5%", "Cambios previos 12%"
   - Gráfica de flujo: asignadas → capturadas → revisadas → aprobadas

4. **P0 - Asignación con versionado** (BE-08)
   - Asignar/reasignar crea evento con incremento de versión
   - Operativo ve historial de "acepté esta tarea en X momento"
   - Responsable efectivo persistido en Firestore para Home

---

### 1.4 ADMIN (rol: ADMIN)

**Permisos actuales:**
- Acceso a todo

**Flujo actual:**
- Escritorio: Acceso completo a Home, Review, asignaciones, catálogo, usuarios
- Móvil: Opcionalmente ve todas las actividades del proyecto (admin view)

**Problemas actuales:**
- Mismos que supervisores + más complejidad sin simplificación
- Desktop sin observabilidad clara de estado de flujo

**Mejoras recomendadas:**
- Iterar sobre supervisores + agregar auditoría detallada

---

## 2. Matriz de Cambios Priorizados

| ID | Descripción | Backend | Mobile | Desktop | Docs | Prioridad |
|----|-------------|---------|--------|---------|------|-----------|
| **BE-01** | Proyección canónica: operational_state, sync_state, review_state, next_action | ✅ Diseño | — | — | ✅ | P0 |
| **BE-02** | Exponer proyección en listados y detalle | ✅ Código | — | — | ✅ | P0 |
| **BE-03** | Review queue consume proyección canónica | ✅ Código | — | ✅ UI | ✅ | P0 |
| **BE-04** | Tipificar errores de sync con `code`, `message`, `retryable`, `suggested_action` | ✅ Código | ✅ Consumo | — | ✅ | P0 |
| **BE-08** | Asignación como evento de dominio con versionado | ✅ Código | ✅ Persistencia | ✅ UI | ✅ | P0 |
| **MO-01** | Home como bandeja de tareas | — | ✅ Reorganizar | — | ✅ | P0 |
| **MO-02** | Sync Center con estados humanos | — | ✅ Reorganizar | — | ✅ | P0 |
| **MO-04** | Persistencia de wizard por paso | — | ✅ DB + UI | — | ✅ | P1 |
| **MO-05** | Reapertura de wizard en último paso | — | ✅ Navegación | — | ✅ | P1 |
| **MO-06** | Resumen de readiness pre-envío | — | ✅ DAO + UI | — | ✅ | P1 |
| **MO-08** | Observaciones estructuradas y acceso al paso | — | ✅ UI de corrección | — | ✅ | P1 |
| **DE-01** | Review queue consumidor de proyección | — | — | ✅ UI | ✅ | P0 |
| **DE-02** | Priorización en review con checkpoints | — | — | ✅ UI | ✅ | P1 |
| **DE-03** | Devoluciones estructuradas | ✅ Schema | — | ✅ Formulario | ✅ | P0 |
| **DE-05** | Dashboard con KPIs operativos | ✅ Endpoint | — | ✅ UI | ✅ | P2 |
| **DOC-01** | Reescribir workflow con 3 dimensiones de estado | — | — | — | ✅ | P0 |

---

## 3. Contrato Canónico del Flujo

### 3.1 Proyección por Actividad (Backend Response)

```json
{
  "uuid": "...",
  "title": "...",
  "operational_state": "PENDIENTE | EN_CURSO | POR_COMPLETAR | BLOQUEADA | CANCELADA",
  "sync_state": "LOCAL_ONLY | READY_TO_SYNC | SYNC_IN_PROGRESS | SYNCED | SYNC_ERROR",
  "review_state": "NOT_APPLICABLE | PENDING_REVIEW | CHANGES_REQUIRED | APPROVED | REJECTED",
  "next_action": "SIN_ACCION | COMPLETAR_WIZARD | REVISAR_ERROR_SYNC | CORREGIR_Y_REENVIAR | SIN_DATOS",
  "sync_error": {
    "code": "NETWORK_ERROR | INVALID_DATA | PERMISSION_DENIED | SERVER_REJECTED | ...",
    "message": "...",
    "retryable": true,
    "suggested_action": "RETRY | CONTACT_SUPPORT | CHECK_DATA | ..."
  },
  "review_observations": [
    {
      "category": "MISSING_DATA | GPS_CRITICAL | MISSING_EVIDENCE | OTHER",
      "severity": "MINOR | MEDIUM | CRITICAL",
      "field": "contexto.estado | evidencias.0 | gps | ...",
      "observation": "...",
      "suggested_action": "EDIT_FIELD | RETAKE_EVIDENCE | CHECK_GPS | ..."
    }
  ],
  "readiness": {
    "is_ready": false,
    "missing": [
      { "field": "contexto.clasificacion", "reason": "required" },
      { "field": "evidencias", "reason": "at_least_1" },
      { "field": "gps", "reason": "critical" }
    ]
  },
  "assigned_to_user_id": "...",
  "assigned_to_user_name": "...",
  "created_by_user_id": "...",
  "sync_version": 123,
  "created_at": "...",
  "updated_at": "..."
}
```

### 3.2 Estados Canónicos

#### Dimensión Operativa
- **PENDIENTE**: Asignada, no iniciada
- **EN_CURSO**: Iniciada, operativo trabajando
- **POR_COMPLETAR**: Iniciada, esperando cierre (wizard abierto)
- **BLOQUEADA**: No puede avanzar (cambios requieren aprobación)
- **CANCELADA**: Cierre sin resolver

#### Dimensión de Sync
- **LOCAL_ONLY**: Creada localmente, no enviada
- **READY_TO_SYNC**: Guardada válida, esperando envío
- **SYNC_IN_PROGRESS**: Siendo enviada en este instante
- **SYNCED**: Backend recibió y procesó
- **SYNC_ERROR**: Falló envío, puede reintentar o requiere intervención

#### Dimensión de Review
- **NOT_APPLICABLE**: No requiere review (ej: cancelada, baja criticidad)
- **PENDING_REVIEW**: Enviada, esperando que coordinador decida
- **CHANGES_REQUIRED**: Coordinador pidió cambios, operativo debe corregir
- **APPROVED**: Coordinador aprobó
- **REJECTED**: Coordinador rechazó (cierre)

#### Acción Siguiente (Computed)
Síntesis de qué debe hacer el usuario AHORA:
- **SIN_ACCION**: Nada, está bien (APPROVED o CANCELLED)
- **COMPLETAR_WIZARD**: Iniciar wizard si está en POR_COMPLETAR
- **REVISAR_ERROR_SYNC**: Hay error de sync, ver qué pasó
- **CORREGIR_Y_REENVIAR**: Cambios requeridos, corregir y resend

---

## 4. Implementación Recomendada

### Fase 1: Backend (P0) - 3 sprints
1. BE-01: Definir DTO proyección canónica
2. BE-02: Exponer en listados y detalle
3. BE-03: Review queue usa proyección
4. BE-04: Tipificación de errores de sync
5. BE-08: Asignación como evento

### Fase 2: Mobile UX (P0) - 2 sprints
1. MO-01: Home reorganizada como bandeja de tareas
2. MO-02: Sync Center con estados legibles
3. Consumidor de BE-01 a BE-04

### Fase 3: Desktop UX (P0) - 2 sprints
1. DE-01: Review queue consumidor canónico
2. DE-03: Devoluciones estructuradas
3. Consumidor de BE-01 a BE-04

### Fase 4: Documentación (P0) - 1 sprint
1. DOC-01-02: Reescribir WORKFLOW.md y SYNC.md

### Fase 5: Incrementales (P1-P2) - iterativo
1. Persistencia de wizard
2. Resumen de readiness
3. Dashboard de KPIs
4. Observaciones estructuradas

---

## 5. Riesgos y Mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|-------------|--------|-----------|
| Cambio de API rompe clientes | ALTA | CRÍTICO | Versionado de API, migration guides, feature flags |
| Falta de cobertura en tests | MEDIA | ALTO | CI tests de contrato al commit |
| Coordinadores no usan nueva UX | MEDIA | ALTO | Capacitación + demo en vivo + metricas |
| Operativos pierden datos en transición | BAJA | CRÍTICO | Persistencia wizard antes de cambios UX |

---

## 6. Siguiente Paso

1. **Aprobación de prioridades**: Confirmar P0 vs descartar extras
2. **BE-01**: Diseñar y revisar DTO proyección con arquitecto
3. **Tests**: Crear pruebas de contrato canónico antes de código
4. **Demo**: Ejecutar con dataset real de TMQ para validar interpretaciones
5. **Rollout**: Feature flags para activar gradualmente por rol

---

## Apéndice: Matriz Actual de Permisos y Recomendaciones

### Roles actuales en permission_catalog.py

```python
"ADMIN": all_permissions
"COORD": Ver/Crear/Editar actividades, Aprobar/Rechazar, Administrar asignaciones
"SUPERVISOR": Ver/Crear/Editar actividades, Aprobar/Rechazar, Ver reportes
"OPERATIVO": Ver/Crear/Editar actividades, Ver catálogo, Crear eventos
"LECTOR": Ver actividades/eventos/catálogo/usuarios/reportes (read-only)
```

**Recomendación:** Mantener actuales. Agregar granularidad una vez el flujo canónico esté estable.
