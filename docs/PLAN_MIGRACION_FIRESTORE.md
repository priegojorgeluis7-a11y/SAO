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
