# BACKLOG - Mejora del Flujo del Sistema

**Fecha:** 2026-03-24  
**Version:** 1.0.0  
**Estado:** Propuesto  
**Objetivo:** traducir el plan de mejora del flujo en historias tecnicas accionables por capa y carpeta del repositorio.

---

## 1. Reglas del backlog

1. No reabrir trabajo marcado como cerrado en `STATUS.md` salvo regresion comprobada.
2. Priorizar cambios que reduzcan ambiguedad de flujo sobre cambios cosmeticos.
3. Cada historia debe cerrar una friccion visible para operativo, coordinacion o soporte.
4. Toda historia que cambie contrato debe actualizar documentacion canonica y pruebas.

---

## 2. Backend

**Carpetas objetivo:**
- `backend/app/api/v1/`
- `backend/app/schemas/`
- `backend/app/services/`
- `backend/app/models/`
- `backend/tests/`

| ID | Prioridad | Carpeta | Historia tecnica | Entregable | Criterios de aceptacion |
|----|-----------|---------|------------------|------------|-------------------------|
| BE-01 | P0 | `backend/app/schemas/` | Definir DTO/proyeccion canonica de flujo por actividad | Schema con `operational_state`, `sync_state`, `review_state`, `next_action` | Una actividad puede representarse sin inferencias cruzadas ni flags locales |
| BE-02 | P0 | `backend/app/api/v1/activities.py` | Exponer la proyeccion canonica en listados y detalle de actividades | Respuestas alineadas al nuevo schema | Mobile y desktop no necesitan recomputar estado compuesto |
| BE-03 | P0 | `backend/app/api/v1/review.py` | Hacer que review queue use la misma proyeccion canonica | Queue homogenea con detalle de siguiente accion | La cola puede filtrarse sin heuristicas paralelas |
| BE-04 | P0 | `backend/app/api/v1/sync.py` | Tipificar errores de sync con codigos estables y metadata de retry | Contrato de error estructurado | Cada error incluye `code`, `message`, `retryable`, `suggested_action` |
| BE-05 | P1 | `backend/app/api/v1/review.py` | Estructurar devoluciones de revision por categoria, severidad, campo y accion | Payload de observaciones accionables | Una devolucion ya no depende solo de texto libre |
| BE-06 | P1 | `backend/app/api/v1/observations.py` | Alinear observaciones con el flujo de correccion | Observaciones consumibles por mobile y desktop | Cada observacion puede apuntar a campo, evidencia o checklist |
| BE-07 | P1 | `backend/app/services/` | Separar semantica de borrador parcial vs item listo para revision | Reglas de validacion por etapa | El backend distingue guardado incremental de submit final |
| BE-08 | P2 | `backend/app/api/v1/assignments.py` | Endurecer asignacion y reasignacion como eventos de dominio con versionado consistente | Mutaciones con incremento de version y responsable efectivo persistido | Asignar, reasignar o retirar no rompe visibilidad en clientes |
| BE-09 | P2 | `backend/app/services/` | Normalizar responsable visible y estado terminal de cancelacion | Regla unica de visibilidad | Home, Planning y Agenda consumen la misma semantica |
| BE-10 | P2 | `backend/app/api/v1/reports.py` | Exponer KPIs operativos del flujo | Endpoint de metricas del proceso | Dashboard no depende solo de `review/queue` |
| BE-11 | P2 | `backend/app/api/v1/` | Agregar resumen de readiness de actividad | Endpoint o campo agregado en detalle | El cliente puede mostrar faltantes antes de enviar |
| BE-12 | P0 | `backend/tests/` | Crear pruebas de contrato para la proyeccion canonica y errores tipificados | Tests unitarios e integracion | Cambios de estado o payload fallan en CI si rompen contrato |

---

## 3. Mobile

**Carpetas objetivo:**
- `frontend_flutter/sao_windows/lib/features/home/`
- `frontend_flutter/sao_windows/lib/features/sync/`
- `frontend_flutter/sao_windows/lib/features/activities/`
- `frontend_flutter/sao_windows/lib/features/agenda/`
- `frontend_flutter/sao_windows/lib/core/database/`
- `frontend_flutter/sao_windows/test/`

| ID | Prioridad | Carpeta | Historia tecnica | Entregable | Criterios de aceptacion |
|----|-----------|---------|------------------|------------|-------------------------|
| MO-01 | P0 | `lib/features/home/` | Reorganizar Home como bandeja de tareas | Secciones: por iniciar, en curso, por completar, corregir, error de envio | El operativo entiende la siguiente accion sin leer estados internos |
| MO-02 | P0 | `lib/features/sync/` | Reorganizar Sync Center con estados humanos | Vistas para esperando red, listo para enviar, enviando, requiere intervencion, sincronizado | El usuario entiende causa y accion por item |
| MO-03 | P0 | `lib/features/agenda/` | Consumir la proyeccion canonica sin recomputar visibilidad local | Agenda alineada al contrato backend | No hay reglas paralelas para responsable visible |
| MO-04 | P1 | `lib/features/activities/wizard/` | Persistir cada paso del wizard | Estado por paso en DB local | Cerrar la app no hace perder avance |
| MO-05 | P1 | `lib/features/activities/wizard/` | Reabrir wizard en el ultimo paso valido | Navegacion de recuperacion | El usuario vuelve exactamente al punto anterior |
| MO-06 | P1 | `lib/features/activities/` | Mostrar readiness antes de enviar | Resumen de faltantes por checklist, GPS y evidencias | El submit final explica por que aun no procede |
| MO-07 | P1 | `lib/features/sync/` | Mostrar errores tipificados y accion sugerida | UI con retry automatico, accion manual y motivo | No se muestran solo mensajes tecnicos crudos |
| MO-08 | P1 | `lib/features/activities/` | Mostrar observaciones estructuradas y acceso al paso afectado | Pantalla de correccion guiada | El usuario puede saltar al campo o evidencia observada |
| MO-09 | P2 | `lib/core/database/` | Ajustar almacenamiento local para estado incremental y resumen de readiness | Columnas/tablas nuevas o extendidas | Los datos parciales sobreviven reinicio y sync |
| MO-10 | P2 | `test/` | Agregar widget/unit tests para Home, Sync Center y wizard recuperable | Suite de regresion focalizada | Regresiones de flujo se detectan en CI |

---

## 4. Desktop

**Carpetas objetivo:**
- `desktop_flutter/sao_desktop/lib/features/operations/`
- `desktop_flutter/sao_desktop/lib/features/dashboard/`
- `desktop_flutter/sao_desktop/lib/features/reports/`
- `desktop_flutter/sao_desktop/lib/data/repositories/`
- `desktop_flutter/sao_desktop/test/`

| ID | Prioridad | Carpeta | Historia tecnica | Entregable | Criterios de aceptacion |
|----|-----------|---------|------------------|------------|-------------------------|
| DE-01 | P0 | `lib/features/operations/` | Hacer que Review Queue consuma la proyeccion canonica | Cola consistente con backend | No usa traducciones paralelas ni heuristicas redundantes |
| DE-02 | P1 | `lib/features/operations/` | Priorizar checklist, GPS, evidencias y observaciones en ValidationPage | Vista de decision rapida | El coordinador identifica problemas antes de decidir |
| DE-03 | P1 | `lib/features/operations/widgets/` | Convertir devolucion de revision en accion estructurada | Formulario de decision con categoria, severidad y accion sugerida | Las devoluciones dejan trazabilidad util para mobile |
| DE-04 | P1 | `lib/data/repositories/` | Consumir errores tipificados y readiness desde backend | Repositorios alineados al nuevo contrato | El desktop ya no interpreta mensajes libres para decidir UX |
| DE-05 | P2 | `lib/features/dashboard/` | Migrar dashboard a KPIs operativos del flujo | Tarjetas y graficas sobre metricas historicas | El avance del dia no depende solo de review queue |
| DE-06 | P2 | `lib/features/reports/` | Alinear reportes a KPIs y estados canonicos | Reportes mas utiles para seguimiento del proceso | Los filtros y exportes usan semantica estable |
| DE-07 | P2 | `test/` | Agregar pruebas de review queue, validation page y dashboard | Cobertura de modulos criticos | Cambios de flujo rompen tests si alteran comportamiento esperado |

---

## 5. QA y E2E

**Carpetas objetivo:**
- `backend/tests/`
- `docs/CHECKLIST_REGRESION.md`
- `backend/scripts/`

| ID | Prioridad | Carpeta | Historia tecnica | Entregable | Criterios de aceptacion |
|----|-----------|---------|------------------|------------|-------------------------|
| QA-01 | P0 | `backend/tests/` | Agregar pruebas de contrato del flujo canonico | Tests de schema y transiciones | Todo cambio incompatible falla temprano |
| QA-02 | P1 | `backend/scripts/` | Extender E2E para cubrir devolucion estructurada y correccion | Script E2E con ciclo approve/rework | El flujo devuelto->corregido->aprobado queda validado |
| QA-03 | P1 | `docs/CHECKLIST_REGRESION.md` | Actualizar regresion con escenarios de Home, Sync Center y wizard recuperable | Casos nuevos del flujo | QA manual cubre las nuevas zonas de riesgo |
| QA-04 | P2 | `backend/tests/` | Medir errores tipificados y reglas de retry | Cobertura sobre `retryable` y `suggested_action` | La API no degrada a mensajes ambiguos |

---

## 6. Documentacion

**Carpetas objetivo:**
- `docs/`
- `IMPLEMENTATION_PLAN.md`

| ID | Prioridad | Carpeta | Historia tecnica | Entregable | Criterios de aceptacion |
|----|-----------|---------|------------------|------------|-------------------------|
| DOC-01 | P0 | `docs/WORKFLOW.md` | Reescribir el contrato funcional con las tres dimensiones de estado | Workflow canonico actualizado | El documento deja clara la diferencia entre operar, sincronizar y revisar |
| DOC-02 | P0 | `docs/SYNC.md` | Alinear sync al nuevo contrato y a errores tipificados | Contrato tecnico actualizado | Sync ya no se describe solo como outbox sino como parte del flujo |
| DOC-03 | P1 | `docs/FLUJO_APP_AS_IS.md` | Actualizar AS-IS a estado real posterior a cierres F0-F5 | Documento sin deuda historica obsoleta | No contradice `STATUS.md` |
| DOC-04 | P1 | `docs/FLUJO_APP_TO_BE.md` | Ajustar TO-BE a tareas visibles, wizard recuperable y revision estructurada | Vision objetivo refinada | El TO-BE sirve como guia de producto y no solo diagrama conceptual |
| DOC-05 | P2 | `docs/SERVICES_MATRIX.md` | Depurar items ya cerrados y reflejar contrato actual | Matriz sin falsos positivos | La matriz vuelve a ser confiable para planeacion |

---

## 7. Orden recomendado de ejecucion

1. BE-01, BE-02, BE-03, BE-04, BE-12
2. MO-01, MO-02, MO-03, DE-01, DOC-01, DOC-02
3. BE-05, BE-06, BE-07, MO-04, MO-05, MO-06, MO-08, DE-02, DE-03
4. BE-08, BE-09, BE-10, BE-11, DE-05, DE-06
5. QA-01, QA-02, QA-03, QA-04, MO-10, DE-07, DOC-03, DOC-04, DOC-05

---

## 8. Definicion de terminado

Una fase de este backlog se considera cerrada cuando:

1. El contrato backend esta publicado y cubierto por pruebas.
2. Mobile y desktop consumen el mismo contrato sin heuristicas paralelas.
3. Hay regresion automatizada y checklist manual para el flujo tocado.
4. La documentacion canonica fue actualizada en la misma entrega.
