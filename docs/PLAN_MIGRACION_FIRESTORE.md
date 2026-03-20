# SAO - Plan de Migracion a Firestore (Opcion C)

**Fecha:** 2026-03-09  
**Version:** 1.2  
**Estado:** Cutover de lectura completado (estabilizacion dual)  
**Objetivo:** Definir la ruta de migracion de persistencia principal de Cloud SQL PostgreSQL a Firestore para reducir costo fijo en baja operacion.

## 1. Resumen ejecutivo
La migracion a Firestore es viable, pero implica cambio arquitectonico (relacional -> documental).  
Para baja operacion puede reducir costo mensual de infraestructura de datos de forma importante, a costa de esfuerzo tecnico y riesgo de migracion.

## 2. Supuestos de costo para estimacion
Escenario solicitado por usuario:
- 300 registros/mes
- 5 fotos max por registro (1,500 fotos/mes)

Supuestos de consumo en backend:
- Cada registro genera varias escrituras adicionales (actividad, timeline, auditoria, estado de sync, metadatos).
- Las fotos se mantienen en Cloud Storage (no en Firestore) y Firestore guarda metadatos.
- Se mantienen Cloud Run + Cloud Storage.

Supuestos de precio (estimado, puede variar por region/fecha):
- Firestore writes: ~USD 0.18 por 100k
- Firestore reads: ~USD 0.06 por 100k
- Firestore deletes: ~USD 0.02 por 100k
- Firestore storage: ~USD 0.18 por GB-mes

## 3. Estimacion de costo mensual (300 registros/mes)

### 3.1 Firestore puro (datos de aplicacion)
Escenario medio:
- Writes: 90,000/mes
- Reads: 180,000/mes
- Deletes: 10,000/mes
- Storage Firestore: 2 a 5 GB

Costo estimado:
- Writes: ~USD 0.16
- Reads: ~USD 0.11
- Deletes: ~USD 0.00
- Storage: ~USD 0.36 a 0.90
- Total Firestore: **~USD 0.7 a 1.5/mes**

### 3.2 Costo total de stack (sin Cloud SQL)
Manteniendo Cloud Run + Storage:
- Cloud Run: ~USD 2 a 12/mes (baja operacion)
- Cloud Storage (1,500 fotos/mes, 1-3 MB): ~USD 0.5 a 6/mes (depende de lecturas/egress)
- Firestore: ~USD 0.7 a 1.5/mes

Total mensual estimado sin Cloud SQL:
- **~USD 3.2 a 19.5/mes**
- Referencia en MXN (17-18): **~$55 a $350 MXN/mes**

## 4. Comparativo simplificado
- Con Cloud SQL actual sobredimensionado: ~USD 160-200/mes (orden de magnitud observado).
- Con Firestore (misma operacion): ~USD 3-20/mes (estimado).
- Ahorro potencial: **~85% a 98%**.

## 5. Impacto tecnico
### 5.1 Cambios necesarios
- Rehacer capa de persistencia (repositorios/servicios) para Firestore.
- Redisenar modelo de datos y consultas (sin joins SQL).
- Ajustar reportes, filtros y agregaciones complejas.
- Implementar indices compuestos en Firestore.
- Definir estrategia de consistencia y transacciones por flujo critico.

### 5.2 Riesgos
- Regresiones funcionales en review/reportes/sync.
- Costos por lectura si no se modela bien denormalizacion.
- Esfuerzo mayor de QA y pruebas E2E.

## 6. Plan de ejecucion recomendado
1. Descubrimiento (3-5 dias)
- Inventario de tablas, consultas y endpoints criticos.

2. Diseno de modelo Firestore (1 semana)
- Colecciones, documentos, indices y reglas.

3. Modo dual de persistencia (1-2 semanas)
- Feature flag `DATA_BACKEND=postgres|firestore|dual`.
- Escritura dual para validar consistencia.

4. ETL y validacion (1 semana)
- Migracion de datos Postgres -> Firestore.
- Conteos y muestreos por entidad.

5. Cutover y estabilizacion (2-3 dias)
- Activar Firestore en produccion.
- Monitoreo intensivo + rollback plan.

## 6.1 Estado de avance en este repo
- [x] Fase 0 iniciada: backend preparado para modo de datos configurable.
	- `DATA_BACKEND=postgres|firestore|dual` en configuracion.
	- Cliente Firestore agregado (`app/core/firestore.py`).
	- Health check compatible con postgres/firestore/dual.
	- Inicializacion SQL condicional para permitir arranque en modo Firestore.
- [x] Fase 1 (parcial): modulo `events` en dual-write.
	- Servicio `EventService` replica create/update/delete a Firestore cuando `DATA_BACKEND=dual`.
	- PostgreSQL se mantiene como fuente canonica durante transicion.
- [x] Fase 1 (parcial): modulo `audit` en dual-write.
	- `write_audit_log(...)` replica en coleccion `audit_logs` en modo dual.
	- Se mantiene modo best-effort para no bloquear transaccion principal.
- [x] Fase 1 (parcial): modulo `activities` en dual-write.
	- `ActivityService` replica create/update/delete/flags a coleccion `activities` en modo dual.
	- PostgreSQL se mantiene como fuente canonica durante transicion.
- [x] Fase 1 (parcial): modulo `review` en dual-write.
	- Decisiones de revision y acciones sobre evidencia se replican a Firestore en modo dual.
	- Actualizacion de estado de actividad en review tambien se refleja en coleccion `activities`.
- [x] Fase 2 (parcial): lectura selectiva desde Firestore para `events` por feature flag.
	- Flag: `FIRESTORE_READ_EVENTS`.
	- Endpoints `GET /events` y `GET /events/{uuid}` intentan lectura Firestore y usan fallback a PostgreSQL en modo dual.
- [x] Fase 2 (parcial): lectura selectiva desde Firestore para `activities` por feature flag.
	- Flag: `FIRESTORE_READ_ACTIVITIES`.
	- Endpoints `GET /activities` y `GET /activities/{uuid}` intentan lectura Firestore y usan fallback a PostgreSQL en modo dual.
- [x] Fase 2: paridad funcional validada (Postgres vs Firestore) en staging para `events` y `activities` en `TMQ`.
- [x] Fase 2: habilitacion de lectura Firestore aplicada en Cloud Run (`FIRESTORE_READ_EVENTS=true`, `FIRESTORE_READ_ACTIVITIES=true`) con fallback en modo `DATA_BACKEND=dual`.

## 7. Criterio de decision
Conviene Opcion C si:
- El objetivo prioritario es reducir costo fijo mensual.
- Se acepta un proyecto de migracion de 4-7 semanas.
- Se prioriza simplicidad de costo sobre modelo relacional tradicional.

No conviene Opcion C si:
- Se necesitan muchas consultas relacionales complejas/reportes SQL.
- Se busca minimizar riesgo de cambio de arquitectura.

## 8. Recomendacion operativa
Antes del cutover final:
- Ejecutar 2 semanas en modo dual.
- Cerrar checklist de regresion funcional completo.
- Validar costo real en Billing export para confirmar el ahorro esperado.

## 9. Validacion de paridad (staging)
Script agregado en repo:
- `backend/scripts/verify_firestore_parity.py`

Objetivo:
- Comparar PostgreSQL vs Firestore en modulos ya migrados (`events`, `activities`).
- Detectar faltantes y diferencias de campos clave antes de cutover de lectura.

Ejecucion sugerida:
1. Configurar variables:
	- `DATABASE_URL`
	- `FIRESTORE_PROJECT_ID`
2. Ejecutar:
	- `python backend/scripts/verify_firestore_parity.py --project-id TMQ`
3. Interpretacion:
	- exit code `0`: paridad OK.
	- exit code `2`: diferencias detectadas (revisar JSON de salida).

Opcional:
- Guardar reporte JSON para evidencia:
  - `python backend/scripts/verify_firestore_parity.py --project-id TMQ --output-json backend/parity_report_tmq.json`

## 10. Ejecucion real y baseline (2026-03-09)
Estado de prerrequisitos en `sao-prod-488416`:
- `firestore.googleapis.com` habilitada.
- Base Firestore `(default)` creada en `us-central1` (modo `FIRESTORE_NATIVE`).

Resultado de ejecucion:
- Comando ejecutado con tunel local Cloud SQL Proxy y salida JSON en `backend/parity_report_tmq.json`.
- Exit code: `2` (paridad incompleta).

Resumen de hallazgos:
- `events`: OK (`postgres_count=0`, `firestore_count=0`).
- `activities`: NO OK (`postgres_count=8`, `firestore_count=0`).
- Diferencia principal: 8 UUID presentes en PostgreSQL y faltantes en Firestore.

Decision operativa:
- No habilitar cutover de lectura total para `activities` hasta completar backfill y repetir paridad con exit code `0`.

## 11. Cierre de brecha y paridad final (2026-03-10)
Accion ejecutada:
- Backfill idempotente de `activities` desde PostgreSQL a Firestore para `project_id=TMQ`.
- Script: `backend/scripts/backfill_firestore_from_postgres.py`.
- Resultado: `activities: postgres=8 planned=8 written=8`.

Ajuste tecnico aplicado:
- Normalizacion de timestamps en `backend/scripts/verify_firestore_parity.py` para evitar falsos positivos por formato (`...` vs `...+00:00`).

Validacion posterior:
- Paridad rerun con salida JSON en `backend/parity_report_tmq.json`.
- Exit code: `0`.
- Resultado:
	- `events`: OK (`postgres_count=0`, `firestore_count=0`).
	- `activities`: OK (`postgres_count=8`, `firestore_count=8`, sin mismatches).

Decision operativa actualizada:
- Se cierra pendiente de paridad de Fase 2 para `events` y `activities` en `TMQ`.
- Se puede continuar con habilitacion progresiva de lectura Firestore por modulo (manteniendo fallback y monitoreo).

## 12. Siguiente paso operativo (cutover controlado)
Flujo recomendado para despliegue gradual:
1. Mantener fallback a PostgreSQL y monitorear errores/latencia por al menos 24-48h.
2. Mantener 2 semanas en modo dual antes de evaluar retiro de Cloud SQL como fuente canonica.
3. Al cierre de ventana dual, ejecutar decision formal: `dual` -> `firestore` como fuente canonica.

## 13. Evidencia de cutover en produccion (2026-03-10)
Cambios aplicados en Cloud Run (`sao-api`, `us-central1`):
- `DATA_BACKEND=dual`
- `FIRESTORE_READ_EVENTS=true`
- `FIRESTORE_READ_ACTIVITIES=true`
- `FIRESTORE_PROJECT_ID=sao-prod-488416`
- `FIRESTORE_DATABASE=(default)`
- `RUN_STARTUP_MIGRATIONS=false`

Revision activa:
- `sao-api-00044-bvt` (100% trafico)

Smoke de salud posterior a deploy:
- `GET /health` -> `status=healthy`
- `checks.postgres=ok`
- `checks.firestore=ok`

## 14. Estado firestore-only y brecha actual (2026-03-10)
Estado observado tras cambiar `DATA_BACKEND=firestore`:
- `GET /health` responde `healthy` con `data_backend=firestore`.
- Rutas de negocio con dependencia SQL (`get_db`) no quedan operativas hasta completar migracion de identidad/catalogos/sync.

Hallazgo clave:
- Coleccion `users` en Firestore sin datos (`users_sample_count=0`).
- Sin usuarios en Firestore, `auth/login` no puede autenticar en modo firestore-only.

Decision tecnica inmediata:
- Completar migracion de identidad a Firestore (usuarios, roles/proyectos) antes de declarar firestore-only productivo.

## 15. Checklist ejecutable para cierre de migracion (P0/P1/P2)

Objetivo de esta seccion:
- Tener una ruta operativa verificable para declarar cierre real de migracion a Firestore.
- Evitar cierre parcial con rutas aun dependientes de SQL.

### 15.1 P0 - Bloqueantes de cierre (obligatorio antes de declarar firestore-only)

- [ ] Inventario final de endpoints SQL-dependientes.
	- Evidencia: lista en `docs/SERVICES_MATRIX.md` marcada por endpoint (`firestore-ok` vs `sql-dependiente`).
- [ ] Migrar autenticacion/autorizacion faltante a Firestore.
	- Incluye: resolucion de usuario actual, roles, permisos y alcance por proyecto sin `get_db`.
	- Evidencia: smoke auth completo con `DATA_BACKEND=firestore` y sin errores 5xx.
- [ ] Migrar flujo de catalogos (lectura y versionado) para no depender de SQL.
	- Incluye: `version/current`, resolucion de version efectiva y validacion de tipos de actividad.
	- Evidencia: app registra actividad con catalogo real del proyecto (sin fallback mock/seed).
- [ ] Migrar flujo sync critico en firestore-only.
	- Incluye: `sync/pull`, `sync/push`, validaciones de catalogo y conflicto basico.
	- Evidencia: corrida E2E con push/pull exitosa en firestore-only.
- [ ] Backfill completo de entidades de negocio pendientes.
	- Evidencia: conteos por entidad/proyecto con desviacion 0 o desviacion explicada/aceptada.

### 15.2 P1 - Estabilizacion y calidad (recomendado para salida productiva segura)

- [ ] Suite de regresion backend en modo firestore-only.
	- Incluir pruebas de `activities`, `review`, `sync`, `catalog`, `auth`.
- [ ] E2E funcional en entorno real (staging o prod controlado) con usuarios reales.
	- Cobertura minima: login, alta actividad, evidencia, review, sync, consulta posterior.
- [ ] Observabilidad y alertamiento.
	- Dashboard con: errores 5xx, latencia p95, errores de Firestore, ratio de fallos sync.
	- Alertas activas para degradacion en auth/sync/catalog.
- [ ] Seguridad operativa.
	- Rotar credenciales temporales usadas en pruebas.
	- Validar secretos vigentes y permisos minimos de servicio.

### 15.3 P2 - Cierre tecnico y reduccion de deuda

- [ ] Retirar codigo dual-write y feature flags ya no requeridos.
	- Mantener solo flags utiles para contingencia real.
- [ ] Limpiar scripts y seeds legacy de SQL no usados en operacion firestore-only.
- [ ] Actualizar runbooks y arquitectura final.
	- `docs/RUNBOOK_CLOUD_RUN.md`, `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`.
- [ ] Definir decision final de Cloud SQL (retiro definitivo o contingencia por ventana limitada).

### 15.4 Definicion de terminado (DoD)

Se considera migracion completada cuando se cumpla todo lo siguiente:
- [ ] `DATA_BACKEND=firestore` en produccion, sin fallback operativo a PostgreSQL.
- [ ] Endpoints criticos de negocio operan sin dependencia SQL.
- [ ] E2E de flujo principal pasa en firestore-only.
- [ ] Monitoreo sin incidentes severos durante ventana de observacion (minimo 7 dias).
- [ ] Documentacion operativa y tecnica actualizada con estado final.

### 15.5 Comandos de validacion sugeridos (evidencia de cierre)

1. Salud del backend:
	 - `GET /health` debe reportar `data_backend=firestore` y `checks.firestore=ok`.
2. Paridad puntual (si aplica a entidades remanentes):
	 - Reusar patron de `backend/scripts/verify_firestore_parity.py` por entidad/proyecto.
3. E2E base:
	 - Ejecutar script E2E local/staging con usuario operativo y aprobador.
4. Verificacion de catalogo efectivo:
	 - Confirmar que app consume catalogo remoto/caché real por proyecto y no assets mock.

### 15.6 Estado actual contra checklist (resumen rapido)

- P0: en progreso (auth basico firestore-only ya funcional; faltan modulos SQL-dependientes de negocio).
- P1: parcial (smoke de salud y login realizados; falta regresion/E2E completa firestore-only).
- P2: pendiente (limpieza final de deuda y cierre documental integral).

## 16. Avance implementado en codigo (2026-03-09, corte actual)

Cambios ya aplicados para desbloquear `DATA_BACKEND=firestore`:

- [x] `GET /catalog/version/current` con resolucion en Firestore.
	- Usa `catalog_current/{PROJECT_ID}` y fallback a `catalog_versions`.
- [x] `GET /catalog/effective` en firestore-only.
	- Soporta lectura de payload efectivo o conversion desde bundle Firestore.
- [x] `GET /catalog/bundle` y `GET /catalog/workflow` en firestore-only.
	- Lectura desde `catalog_bundles` (por proyecto/version).
- [x] `GET /catalog/check-updates` en firestore-only.
	- Compara `current_hash` contra hash/version publicado en Firestore.
- [x] `GET /catalog/versions?project_ids=...` en firestore-only.
	- Retorna digest ligero por proyecto (version/hash/fecha).
- [x] `POST /sync/pull` en firestore-only.
	- Cursor por `since_version`/`after_uuid`/`until_version`/`limit`.
- [x] `POST /sync/push` en firestore-only.
	- Upsert por `uuid`, manejo de conflictos y `force_override`.
	- Validacion de `catalog_version_id` y `activity_type_code` contra catalogo Firestore.

Pendiente inmediato (siguiente bloque tecnico):
- [x] `GET /catalog/versions` listado detallado (no digest) en firestore-only para `project_id`.
- [x] Endpoints editor/admin de catalogo (`project-ops`, `validate`, `publish`, `rollback`) en firestore-only.
	- Persistencia de estado editable/publicado y rollback sobre `catalog_bundles`, `catalog_versions`, `catalog_current`.
- [ ] Suite de pruebas de regresion para los nuevos flujos firestore-only.
	- Avance: tests de regresion firestore-only agregados para endpoints admin de catalogo en `backend/tests/test_catalog_bundle.py` (`project-ops`, `validate`, `publish`, `rollback`).
	- Avance: tests de regresion firestore-only agregados para `sync` en `backend/tests/test_sync.py` (`pull`, `push`, verificacion de rama Firestore).
	- Avance: tests de regresion firestore-only agregados para `auth` en `backend/tests/test_auth.py` (login exitoso/error y control de acceso por proyecto en modo Firestore).
	- Avance: tests integrados firestore-only `auth + catalog + sync` agregados en `backend/tests/test_firestore_e2e_flow.py` (flujo happy-path, control de alcance por proyecto y validacion de `activity_type_code` contra catalogo).
	- Avance: smoke suite unificada agregada en `backend/scripts/run_firestore_regression_smoke.ps1`.
	- Avance: smoke suite integrada en CI (`.github/workflows/backend-ci.yml`, job `firestore-smoke`).
	- Resultado actual del smoke suite: `4 passed` (catalog) + `2 passed` (sync) + `3 passed` (auth) + `3 passed` (integrado auth+catalog+sync).
	- Pendiente: ampliar cobertura E2E/regresion para flujos completos de `sync` + `catalog` + `auth` en modo firestore-only.
