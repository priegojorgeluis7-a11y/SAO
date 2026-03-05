# Plan de Correccion de Gaps Prioridad Media

**Fecha:** 2026-03-05
**Fuente base:** `docs/FUNCIONES_SISTEMA.md`
**Objetivo:** cerrar los gaps de prioridad media con evidencia en codigo y un plan ejecutable por fases.

## 1. Diagnostico Consolidado

### 1.1 Gaps media del inventario y estado real

| Gap (inventario) | Estado real | Evidencia tecnica | Decision |
|---|---|---|---|
| Prefijo `/observations` sin `/api/v1` | CERRADO (falso positivo) | `backend/app/main.py` monta `observations.router` con `prefix=settings.API_V1_STR`; tests usan `/api/v1/observations` | Retirar del backlog MEDIA y marcar como resuelto documentalmente |
| `GET /assignments` sin endpoint de creacion | CERRADO (falso positivo) | `backend/app/api/v1/assignments.py` incluye `POST /assignments`; desktop usa `AssignmentsRepository.createAssignment()` a `/api/v1/assignments` | Retirar del backlog MEDIA y actualizar inventario |
| Mobile `ProjectsPage` estatica | VIGENTE | `frontend_flutter/sao_windows/lib/features/projects/projects_page.dart` usa lista `_projects` hardcoded | Implementar carga remota y seleccion de proyecto activa |
| Mobile sincronizacion de assignments (solo local) | VIGENTE | `AgendaController.addAssignmentOptimistic()` solo agrega en memoria; `AssignmentsRepository` solo hace `GET /assignments`; `AssignmentSyncServiceNoOp` | Implementar flujo create/persist/sync de assignments en mobile |
| Desktop editor catalogo tabs avanzados sin endpoint mapeado | PARCIAL / desactualizado | Backend tiene endpoints `/catalog/editor/*` para activities, subcategories, purposes, topics, results, attendees; desktop usa `_patchProjectOps` | Cerrar gap de endpoint. Mantener solo hardening de integracion y pruebas de contrato |
| Desktop reportes sin endpoint dedicado firmado | VIGENTE | `reports_provider.dart` consume `GET /api/v1/review/queue` y arma PDF local | Crear endpoint de reporte server-side con metadata auditable |
| Dashboard KPIs calculados desde cola de revision | VIGENTE | `dashboard_provider.dart` calcula avance con counters de `/review/queue` | Crear endpoint de KPIs operativos historicos y migrar dashboard |
| Cobertura desktop fuera de auth limitada | VIGENTE | Pocas pruebas en `desktop_flutter/sao_desktop/test/`; no se observan suites dedicadas para reports/dashboard/planning end-to-end | Aumentar cobertura minima por modulo critico |

### 1.2 Conclusiones del analisis

- Total revisado como MEDIA en inventario: 8 items.
- Vigentes y a corregir: 5 items.
- Falsos positivos o desactualizados: 3 items.
- Riesgo principal actual: desalineacion entre inventario documental y estado real del codigo.

## 2. Plan de Correccion por Fases

## Fase A (Rapida, 2-3 dias)

**Meta:** limpiar backlog y estabilizar integraciones existentes.

1. Actualizar inventario de gaps en `docs/FUNCIONES_SISTEMA.md`.
2. Mover a "resuelto" los gaps de observations y assignments backend.
3. Reclasificar "editor de catalogo tabs avanzados" como "hardening/pruebas", no como falta de endpoint.
4. Agregar checklist de validacion rapida de contratos desktop catalogo (create/update/delete por entidad).

**Criterio de salida:** inventario de gaps sin falsos positivos y validado contra codigo.

## Fase B (Producto Mobile, 4-6 dias)

**Meta:** cerrar los 2 gaps media vigentes de la app movil.

### B1. `ProjectsPage` conectada a backend

- Implementar `ProjectsRepository` en mobile para consumir `/projects`.
- Reemplazar lista estatica por datos remotos con cache local minima.
- Integrar seleccion de proyecto con estado global activo (mismo proyecto usado por Home, Agenda y Sync).
- Manejar estados: loading, error, retry, y fallback offline.

**Criterios de aceptacion:**
- La lista de proyectos refleja backend en tiempo real.
- Cambiar proyecto impacta Home/Agenda/Sync sin reiniciar app.
- Sin datos hardcoded de proyectos en UI.

### B2. Sincronizacion real de assignments en Agenda

- Persistir asignaciones creadas desde dispatcher en tabla local con `sync_status=local_pending`.
- Crear flujo de push `POST /assignments` para items pendientes.
- Marcar estados `synced`/`error` con retry y trazabilidad.
- Conectar `SyncOrchestrator` a un `AssignmentSyncService` real (reemplazar `NoOp`).

**Criterios de aceptacion:**
- Crear assignment en Agenda lo envia a backend cuando hay red.
- En offline queda en cola y sincroniza despues.
- Pull posterior refleja asignacion en otros clientes.

## Fase C (Desktop + Backend de negocio, 5-7 dias)

**Meta:** corregir calidad de decision operativa y auditabilidad.

### C1. Endpoint de reportes auditable

- Diseñar `GET /reports/activities` (o `POST /reports/generate`) con filtros:
  - `project_id`, `front`, `date_from`, `date_to`, `status`.
- Incluir metadata de auditoria en respuesta (generated_at, generated_by, source_hash, trace_id).
- Opcional: endpoint de archivo firmado o hash verificable para PDF.
- Migrar `ReportsPage` para usar el endpoint dedicado en lugar de `review/queue`.

**Criterios de aceptacion:**
- El reporte se genera desde fuente backend trazable.
- La salida incluye metadata verificable de auditoria.
- El PDF local consume datos del endpoint de reporte.

### C2. KPIs operativos reales para Dashboard

- Crear endpoint de KPIs historicos (ej. `/dashboard/kpis`) desacoplado de cola de revision.
- Definir metricas minimas:
  - actividades completadas del dia,
  - aprobacion diaria real,
  - SLA de revision,
  - backlog real por estado.
- Ajustar formula de avance en desktop para usar denominador operativo, no solo cola.

**Criterios de aceptacion:**
- "Avance del dia" no depende de `review/queue`.
- Los KPIs coinciden con consultas de validacion en BD.
- Dashboard mantiene tiempos de carga aceptables.

## Fase D (Calidad, 3-4 dias en paralelo)

**Meta:** elevar confianza de cambios en desktop.

- Agregar pruebas unitarias/widget para:
  - `features/reports` (filtros, fuente de datos, generacion),
  - `features/dashboard` (calculo de KPIs y rendering de estados),
  - `features/planning` (crear assignment y manejo de errores),
  - `features/catalogs` (CRUD por entidad y mapeo de operaciones).
- Definir umbral minimo de cobertura por modulo critico (objetivo inicial: >= 60%).
- Integrar corrida de tests desktop en CI.

**Criterios de aceptacion:**
- Suites nuevas estables en CI.
- Cobertura minima alcanzada para modulos priorizados.
- Fallas de contrato UI/API detectables por tests.

## 3. Priorizacion Ejecutiva

1. Fase A: limpieza de backlog documental (evita decisiones basadas en ruido).
2. Fase B: gaps mobile que afectan operacion diaria (proyectos + assignments).
3. Fase C: reporteria y KPIs (impacto en control supervisor y trazabilidad).
4. Fase D: cobertura y prevencion de regresiones (paralela desde mitad de Fase B).

## 4. Riesgos y Dependencias

- Dependencia de definicion funcional para KPI oficial de "avance del dia".
- Dependencia de producto/compliance para nivel de firma o hash de reportes.
- Riesgo de duplicidad de assignments si no se define idempotencia (recomendado: `client_assignment_uuid`).
- Riesgo de drift documental si no se actualiza inventario tras cada release.

## 5. Entregables Esperados

1. Inventario de gaps media actualizado y consistente con codigo.
2. Mobile sin proyectos hardcoded y con sync de assignments operativo.
3. Backend con endpoint dedicado de reportes y endpoint de KPIs operativos.
4. Desktop consumiendo nuevas APIs para reportes/dashboard.
5. Cobertura de tests desktop ampliada en modulos criticos.

## 6. Estado de Ejecucion y Validacion (2026-03-05)

### 6.1 Avance por fase

- Fase A: COMPLETADA (inventario depurado y falsos positivos cerrados).
- Fase B: COMPLETADA en alcance principal (ProjectsPage con backend + sync real de assignments).
- Fase C: COMPLETADA en alcance minimo funcional (endpoints backend de reportes/KPIs + consumo desktop).
- Fase D: AVANCE PARCIAL (tests agregados y estabilizacion de contratos en modulos tocados).

### 6.2 Evidencia de validacion tecnica ejecutada

- Backend focal `dashboard/reports`: `2 passed`.
- Backend integration `review/observations`: `12 passed` (ejecucion con marker `integration`).
- Backend completo: `100 passed, 31 deselected`.
- Mobile Flutter completo (`frontend_flutter/sao_windows`): `223 tests passed`.
- Desktop Flutter completo (`desktop_flutter/sao_desktop`): `59 tests passed`.

### 6.3 Ajustes de estabilizacion aplicados durante regression

- `backend/app/api/v1/reports.py`: reemplazo de `datetime.utcnow()` por `datetime.now(timezone.utc)`.
- `frontend_flutter/sao_windows/test/core/routing/app_router_redirect_test.dart`: expectativa alineada al redirect actual `"/"`.
- `frontend_flutter/sao_windows/test/features/agenda/data/assignments_repository_test.dart`: fake local store actualizado con metodos de interfaz nuevos.
- `frontend_flutter/sao_windows/test/features/auth/application/logout_flow_test.dart`: firma de `bootstrap()` actualizada a `Future<BootstrapResult>`.

### 6.4 Riesgo residual inmediato

- Los `31 deselected` en backend corresponden a suites fuera del set por defecto (ej. tests marcados); para cierre de release se recomienda corrida explicita por markers requeridos en el pipeline.
