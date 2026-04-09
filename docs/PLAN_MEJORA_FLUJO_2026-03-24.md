# PLAN - Mejora del Flujo del Sistema

**Fecha:** 2026-03-24  
**Version:** 1.0.0  
**Estado:** Propuesto  
**Alcance:** backend, mobile, desktop, QA y documentacion  
**Base:** `STATUS.md`, `IMPLEMENTATION_PLAN.md`, `docs/WORKFLOW.md`, `docs/SYNC.md`, `docs/AUDIT_REPORT.md`

---

## 1. Objetivo

Endurecer el flujo operativo de punta a punta para que asignacion, ejecucion, captura, sincronizacion y revision funcionen como un solo proceso observable, consistente y accionable.

Este plan no reemplaza F0-F5. Lo complementa en la etapa post-cierre base, enfocandose en calidad del flujo y reduccion de ambiguedad operativa.

---

## 2. Diagnostico resumido

El sistema ya cuenta con la mayoria de capacidades base. El siguiente cuello de botella es de experiencia y contrato de flujo:

1. El mismo registro se interpreta con varias capas de estado: ejecucion, sync y revision.
2. El operativo sigue expuesto a estados tecnicos que no siempre indican la siguiente accion.
3. La devolucion de revision todavia depende demasiado de texto libre o de lectura manual del detalle.
4. Sync y asignaciones ya funcionan, pero necesitan una semantica mas robusta para evitar invisibilidad, confusiones y soporte reactivo.
5. Dashboard y reportes todavia pueden mejorar si miden el flujo real y no solo volumen o colas tecnicas.

---

## 3. Principios de la mejora

### 3.1 Flujo unico
- Una actividad debe poder seguirse sin saltos conceptuales desde asignacion hasta cierre aprobado.

### 3.2 Tareas visibles
- El usuario debe ver acciones concretas, no estados internos del sistema.

### 3.3 Recuperabilidad total
- Ninguna captura debe perderse por salida del wizard, cambio de pantalla o conectividad.

### 3.4 Errores accionables
- Todo error de sync o revision debe explicar causa, impacto y accion correctiva.

### 3.5 Observabilidad operativa
- Las metricas deben reflejar friccion real del proceso, no solo cantidad de registros.

---

## 4. Modelo objetivo del flujo

Se propone separar explicitamente tres dimensiones:

### 4.1 Estado operativo
- `PENDIENTE`
- `EN_CURSO`
- `POR_COMPLETAR`
- `BLOQUEADA`
- `CANCELADA`

### 4.2 Estado de sync
- `LOCAL_ONLY`
- `READY_TO_SYNC`
- `SYNC_IN_PROGRESS`
- `SYNCED`
- `SYNC_ERROR`

### 4.3 Estado de revision
- `NOT_APPLICABLE`
- `PENDING_REVIEW`
- `CHANGES_REQUIRED`
- `APPROVED`
- `REJECTED`

### 4.4 Regla de oro

La UI no debe inferir comportamiento cruzando valores crudos de varias tablas o heuristicas locales. Debe consumir una proyeccion canonica del flujo desde backend y derivar sobre ella las bandejas de trabajo.

---

## 5. Mejoras priorizadas

## P0 - Contrato unico de flujo

**Objetivo:** que backend, mobile y desktop consuman la misma historia de estado.

### Cambios esperados
- Backend expone una proyeccion canonica por actividad con estado operativo, estado de sync, estado de revision y siguiente accion sugerida.
- Mobile usa esa proyeccion para Home, Agenda, Sync Center y detalle.
- Desktop usa esa misma proyeccion para Review Queue, dashboard operativo y paneles de detalle.

### Resultado esperado
- Menos logica duplicada.
- Menos desaparicion aparente de actividades.
- Menos interpretaciones distintas entre equipos.

---

## P1 - Flujo orientado a tareas

**Objetivo:** que el operativo vea trabajo pendiente y no estados tecnicos.

### Cambios esperados
- Home se reorganiza en bandejas: por iniciar, en curso, por completar, devueltas para correccion, con error de envio.
- Sync Center muestra estados humanos: esperando red, listo para enviar, enviando, requiere intervencion, sincronizado.
- Cada tarjeta muestra por separado progreso operativo y progreso administrativo.

### Resultado esperado
- Menor carga cognitiva.
- Menor necesidad de soporte para interpretar el sistema.
- Mejor tasa de cierre correcto en primer intento.

---

## P1 - Wizard incremental y recuperable

**Objetivo:** que el usuario nunca pierda avance y siempre sepa que falta.

### Cambios esperados
- Cada paso del wizard persiste localmente.
- El wizard reabre en el ultimo punto valido.
- Cada paso se marca como completo, incompleto o bloqueado.
- Antes de enviar, se muestra un resumen de readiness con faltantes puntuales.

### Resultado esperado
- Menos recaptura.
- Menos errores al final del flujo.
- Mayor confianza del operativo en modo offline.

---

## P1 - Revision estructurada

**Objetivo:** que una actividad devuelta sea corregible en un solo ciclo.

### Cambios esperados
- Backend devuelve observaciones estructuradas con categoria, severidad, campo afectado, evidencia afectada y accion sugerida.
- Desktop prioriza problemas en checklist, GPS, evidencias y consistencia de catalogo antes de la decision final.
- Mobile presenta la devolucion como lista de correcciones accionables con acceso directo al paso afectado.

### Resultado esperado
- Menos rechazos ambiguos.
- Menos ciclos de ida y vuelta.
- Mayor trazabilidad de la decision de coordinacion.

---

## P2 - Asignacion y visibilidad robustas

**Objetivo:** que ninguna actividad desaparezca del flujo visible por detalles de sync o del responsable efectivo.

### Cambios esperados
- Toda asignacion o reasignacion incrementa version y deja responsable efectivo persistido.
- Toda cancelacion o retiro de agenda usa un estado terminal o soft-delete semantico claro.
- Las vistas consumen la misma regla de responsable visible.

### Resultado esperado
- Menos incidencia de "desaparecio de Home/Planning".
- Menos hotfixes de `sync_version` o de fallback de assignee.

---

## P2 - KPIs operativos

**Objetivo:** medir salud del flujo y no solo volumen.

### KPIs sugeridos
- tiempo asignacion -> inicio
- tiempo fin -> captura completa
- tiempo captura -> sync exitosa
- tiempo en revision
- tasa de devolucion por tipo de actividad
- tasa de error por causa de sync
- backlog por siguiente accion

### Resultado esperado
- Priorizacion basada en friccion real.
- Dashboard y reportes mas utiles para coordinacion.

---

## 6. Secuencia recomendada por sprint

## Sprint 1
- Contrato unico de flujo en backend.
- Consumo base en mobile Home y Sync Center.
- Consumo base en desktop Review Queue.
- Ajuste documental minimo en workflow y sync.

## Sprint 2
- Wizard incremental y recuperable.
- Devolucion estructurada de revision.
- Navegacion directa desde observacion al paso afectado.

## Sprint 3
- Endurecimiento de asignaciones y visibilidad.
- Tipologias de error de sync con acciones.
- KPIs operativos de flujo.

## Sprint 4
- Regresion E2E del flujo completo.
- Ajustes UX finales.
- Limpieza documental y consolidacion de fuentes canonicas.

---

## 7. Dependencias

1. Backend debe publicar el contrato canonico antes del ajuste fuerte de Home, Sync Center y Review Queue.
2. Mobile y desktop deben eliminar heuristicas locales una vez disponible la nueva proyeccion.
3. QA necesita escenarios E2E por flujo, no solo por endpoint o modulo.
4. Documentacion debe consolidar `WORKFLOW.md` y `SYNC.md` como contratos canonicos del flujo.

---

## 8. Criterios de exito

1. El operativo identifica su siguiente accion sin interpretar estados internos.
2. Las actividades no cambian de visibilidad por detalles accidentales de sync o asignacion.
3. Las devoluciones de revision se corrigen en un solo ciclo con mayor frecuencia.
4. Los errores de sync informan causa, politica de retry y accion manual si aplica.
5. Dashboard y reportes muestran salud del flujo con KPIs operativos historicos.

---

## 9. Entregables

1. Contrato canonico de flujo en backend y documentacion asociada.
2. Home y Sync Center orientados a tareas en mobile.
3. Wizard incremental y recuperable.
4. Review Queue y ValidationPage con devolucion estructurada.
5. Endpoints de KPIs operativos y reportes mejor alineados al proceso.
6. Suite E2E del flujo completo y checklist de regresion actualizado.

---

## 10. Documento complementario

El backlog tecnico accionable de este plan se encuentra en:

- `docs/BACKLOG_MEJORA_FLUJO_2026-03-24.md`
