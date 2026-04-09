# TICKETS P0 - Mejora del Flujo del Sistema

**Fecha:** 2026-03-24  
**Version:** 1.0.0  
**Estado:** Listo para ejecucion  
**Fuente:** `docs/BACKLOG_MEJORA_FLUJO_2026-03-24.md`

---

## Objetivo

Convertir el paquete P0 del backlog en tickets implementables por equipo, con alcance, dependencias y criterios de aceptacion verificables.

P0 incluido:

- Backend: BE-01, BE-02, BE-03, BE-04, BE-12
- Mobile: MO-01, MO-02, MO-03
- Desktop: DE-01
- QA/Docs: QA-01, DOC-01, DOC-02

---

## Convenciones para ejecucion

1. Cada ticket debe salir con tests o evidencia de validacion.
2. Todo cambio de contrato requiere ajuste documental en la misma entrega.
3. No mergear cambios de UI que dependan de contrato nuevo sin feature flag o compatibilidad temporal.

---

## Ticket P0-01 - Backend schema canonico de flujo

**Backlog base:** BE-01  
**Owner sugerido:** Backend  
**Carpeta:** `backend/app/schemas/`

### Historia
Como cliente mobile/desktop, necesito una proyeccion canonica de estado para no recomputar estado compuesto con heuristicas locales.

### Alcance
1. Definir schema con: `operational_state`, `sync_state`, `review_state`, `next_action`.
2. Documentar enums y significado.
3. Mantener compatibilidad temporal con campos legacy si aplica.

### Fuera de alcance
1. Cambio de UX en mobile/desktop.
2. KPIs o reportes.

### Criterios de aceptacion
1. El schema compila y se usa en respuestas de prueba.
2. Todos los valores validan contra enums declarados.
3. Existe documentacion breve del contrato en `docs/WORKFLOW.md`.

### Evidencia esperada
1. Diff en schema.
2. Tests unitarios de serializacion/deserializacion.

---

## Ticket P0-02 - Backend activities expone proyeccion canonica

**Backlog base:** BE-02  
**Owner sugerido:** Backend  
**Carpeta:** `backend/app/api/v1/activities.py`

### Historia
Como cliente, necesito recibir la proyeccion canonica en listados y detalle para evitar logica paralela por plataforma.

### Alcance
1. Incluir proyeccion canonica en endpoints de actividades.
2. Alinear mapeo entre datos persistidos y estados expuestos.
3. Mantener consistencia entre listados y detalle.

### Dependencias
1. P0-01 completado.

### Criterios de aceptacion
1. `GET` de actividades devuelve la proyeccion en todos los items.
2. `GET` de detalle devuelve la misma semantica de estado.
3. Tests de contrato pasan.

---

## Ticket P0-03 - Backend review queue usa contrato unico

**Backlog base:** BE-03  
**Owner sugerido:** Backend  
**Carpeta:** `backend/app/api/v1/review.py`

### Historia
Como coordinacion, necesito que la cola de revision use la misma proyeccion de flujo que activities para evitar ambiguedad de estado.

### Alcance
1. Exponer estados canonicos y siguiente accion en review queue.
2. Eliminar dependencias de heuristicas de texto para clasificacion principal.

### Dependencias
1. P0-01 completado.

### Criterios de aceptacion
1. La cola se puede filtrar por estados estructurados.
2. No depende de coincidencia textual en descripcion para casos base.
3. Tests de endpoint y contrato en verde.

---

## Ticket P0-04 - Backend errores de sync tipificados

**Backlog base:** BE-04  
**Owner sugerido:** Backend  
**Carpeta:** `backend/app/api/v1/sync.py`

### Historia
Como operativo, necesito errores de sync accionables para saber si esperar retry o intervenir manualmente.

### Alcance
1. Normalizar respuestas de error con `code`, `message`, `retryable`, `suggested_action`.
2. Tipificar al menos: red, auth, permisos, validacion, conflicto, payload.
3. Documentar contrato en `docs/SYNC.md`.

### Criterios de aceptacion
1. Errores de sync devuelven estructura estable.
2. Se conserva trazabilidad por item fallido en batch.
3. Tests de contrato para errores y conflictos pasan.

---

## Ticket P0-05 - Backend pruebas de contrato P0

**Backlog base:** BE-12, QA-01  
**Owner sugerido:** Backend + QA  
**Carpeta:** `backend/tests/`

### Historia
Como equipo, necesito pruebas de contrato para detectar regresiones del flujo antes de llegar a clientes.

### Alcance
1. Tests para schema canonico de flujo.
2. Tests para endpoints de activities/review con proyeccion.
3. Tests para errores tipificados de sync.

### Criterios de aceptacion
1. Suite de contrato ejecutable en CI.
2. Falla al remover o alterar campos obligatorios.
3. Cubre escenarios de conflicto y retryable/no-retryable.

---

## Ticket P0-06 - Mobile Home orientada a tareas

**Backlog base:** MO-01  
**Owner sugerido:** Mobile  
**Carpeta:** `frontend_flutter/sao_windows/lib/features/home/`

### Historia
Como operativo, necesito ver tareas pendientes de forma directa para identificar la siguiente accion sin interpretar estados internos.

### Alcance
1. Crear secciones: por iniciar, en curso, por completar, por corregir, error de envio.
2. Consumir proyeccion canonica de backend.
3. Mantener fallback visual compatible mientras migra el contrato.

### Dependencias
1. P0-01 y P0-02 disponibles.

### Criterios de aceptacion
1. Home renderiza por siguiente accion.
2. Una misma actividad no aparece en secciones incompatibles.
3. Tests widget de agrupacion pasan.

---

## Ticket P0-07 - Mobile Sync Center orientado a accion

**Backlog base:** MO-02  
**Owner sugerido:** Mobile  
**Carpeta:** `frontend_flutter/sao_windows/lib/features/sync/`

### Historia
Como operativo, necesito entender cada error de sync y la accion recomendada.

### Alcance
1. Mostrar estados humanos de sync.
2. Renderizar `retryable` y `suggested_action` por item.
3. Exponer accion de reintento cuando aplique.

### Dependencias
1. P0-04 disponible.

### Criterios de aceptacion
1. No se muestran solo mensajes tecnicos crudos.
2. Cada error visible incluye accion sugerida.
3. Tests de parsing y render de errores tipificados pasan.

---

## Ticket P0-08 - Mobile Agenda sin recomputo local de visibilidad

**Backlog base:** MO-03  
**Owner sugerido:** Mobile  
**Carpeta:** `frontend_flutter/sao_windows/lib/features/agenda/`

### Historia
Como operativo, necesito que agenda y home muestren la misma realidad de actividades sin reglas distintas entre pantallas.

### Alcance
1. Consumir contrato canonico para visibilidad.
2. Eliminar reglas paralelas de inferencia principal.
3. Validar consistencia con Home.

### Dependencias
1. P0-01 y P0-02 disponibles.

### Criterios de aceptacion
1. Agenda y Home coinciden en clasificacion de actividad.
2. No hay desaparicion por logica local divergente.
3. Tests de consistencia entre vistas pasan.

---

## Ticket P0-09 - Desktop Review Queue sobre contrato canonico

**Backlog base:** DE-01  
**Owner sugerido:** Desktop  
**Carpeta:** `desktop_flutter/sao_desktop/lib/features/operations/`

### Historia
Como coordinacion, necesito una cola consistente con backend para decidir mas rapido y con menos ambiguedad.

### Alcance
1. Consumir campos canonicos en cola de revision.
2. Reemplazar heuristicas de clasificacion principal.
3. Mantener filtros funcionales por estado y flags estructurados.

### Dependencias
1. P0-03 disponible.

### Criterios de aceptacion
1. Cola filtra por estados estructurados.
2. No depende de text matching para flujo base.
3. Tests de provider/repository pasan.

---

## Ticket P0-10 - Documentacion canonica del flujo

**Backlog base:** DOC-01, DOC-02  
**Owner sugerido:** Backend + Documentacion  
**Carpeta:** `docs/`

### Historia
Como equipo, necesito una fuente canonica de workflow y sync para evitar decisiones con documentacion desactualizada.

### Alcance
1. Mantener `docs/WORKFLOW.md` y `docs/SYNC.md` alineados al contrato P0.
2. Registrar cambios de contrato en release notes internas.

### Criterios de aceptacion
1. Ambos documentos reflejan campos y semantica vigente.
2. No hay contradicciones entre workflow y sync.
3. Se enlazan desde `docs/README.md` y plan maestro cuando aplique.

---

## 11. Orden de ejecucion sugerido

1. P0-01
2. P0-02
3. P0-03
4. P0-04
5. P0-05
6. P0-06
7. P0-07
8. P0-08
9. P0-09
10. P0-10

---

## 12. Checklist de salida P0

1. Contrato canonico publicado y probado en backend.
2. Mobile y desktop consumen contrato sin heuristicas principales paralelas.
3. Errores de sync son accionables en UI.
4. Documentacion canonica actualizada en la misma ventana de entrega.
