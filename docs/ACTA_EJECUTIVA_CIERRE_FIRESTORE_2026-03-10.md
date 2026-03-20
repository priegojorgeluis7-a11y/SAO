# Acta Ejecutiva — Cierre Firestore SAO

Fecha: 2026-03-10  
Proyecto: SAO  
Entorno: Produccion (Cloud Run `sao-api`, `us-central1`)  
Revision activa: `sao-api-00062-v8v`

## 1) Decision Ejecutiva

**GO OPERATIVO**

El backend productivo opera en modo Firestore-only, con flujo principal validado end-to-end y estabilidad recuperada tras incidente de capacidad.

## 2) Estado Actual

- Runtime de datos: `DATA_BACKEND=firestore`.
- Cloud SQL en runtime Cloud Run: desacoplado (`run.googleapis.com/cloudsql-instances: ''`).
- Trafico: `100%` a revision `sao-api-00062-v8v`.
- Smoke productivo: en verde (`health`, `login`, `activities`).

## 3) Evidencia de Cierre

1. Regresion Firestore (suite automatizada): PASS
- `test_catalog_bundle`: 4 passed
- `test_sync`: 2 passed
- `test_auth`: 3 passed
- `test_firestore_e2e_flow`: 3 passed

2. E2E real en produccion: PASS
- Flujo: operativo push -> supervisor decision -> operativo pull
- `Activity UUID`: `328256b9-3ba6-4219-b43e-f78484396f80`
- `Push status`: `CREATED`
- `Final execution_state`: `COMPLETADA`

3. Incidente Cloud Run 429
- Causa observada: `no available instance` en revision inestable.
- Mitigacion aplicada: retiro de revision afectada + reenrutamiento a revision estable + ajustes de despliegue.
- Estado: **RESUELTO**.

## 4) Riesgo Residual (No Bloqueante)

- Monitoreo recomendado por 7 dias para confirmar ausencia de regresion en disponibilidad (`429`/`5xx`) tras la ventana de cambios.

## 5) Acciones de Seguimiento

1. Mantener smoke post-deploy obligatorio en cada release.
2. Vigilar logs/metricas de disponibilidad por 7 dias (SLO de health y auth/login).
3. Continuar mejora de cobertura desktop no-auth (no bloquea operacion backend).

## 6) Referencias

- `STATUS.md`
- `docs/AUDITORIA_MIGRACION_FIRESTORE.md`
- `docs/EVIDENCIA_CIERRE_FIRESTORE.md`
- `docs/INCIDENTE_CLOUD_RUN_429_2026-03-10.md`
