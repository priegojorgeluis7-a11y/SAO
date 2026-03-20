# Incidente Cloud Run 429 — SAO API

Fecha: 2026-03-10
Servicio: `sao-api`
Proyecto: `sao-prod-488416`
Region: `us-central1`
URL: `https://sao-api-fjzra25vya-uc.a.run.app`

## Resumen

El servicio presenta respuestas `429` recurrentes en `GET /health` con mensaje de plataforma:

`The request was aborted because there was no available instance.`

El problema persistio durante varias revisiones, pero quedo mitigado en la misma ventana operativa.

## Estado

- **RESUELTO** (mitigacion operativa aplicada en la misma fecha).

## Revision activa

- Revision: `sao-api-00062-v8v`
- Trafico: `100%`
- Configuracion observada:
  - `autoscaling.knative.dev/minScale: 2`
  - `autoscaling.knative.dev/maxScale: 100`
  - `containerConcurrency: 200`
  - CPU/memoria: `1 vCPU`, `512Mi`
   - Cloud SQL binding: vacio (`run.googleapis.com/cloudsql-instances: ''`)

## Evidencia tecnica

1. Durante incidente:
   - Sondeo de salud (20 intentos, cada 2s): `HEALTH_OK=0 HEALTH_ERR=20`.

2. Durante incidente, logs de Cloud Run con `429`:
   - Varias entradas consecutivas en `sao-api-00059-vgv` para `/health`.
   - Mensaje constante: `no available instance`.

3. Estado de revision afectada (`gcloud run revisions describe sao-api-00059-vgv`):
   - `Ready: Unknown`
   - `Reason: MinInstancesWarming`
   - `MinInstancesProvisioned: Unknown`
   - `Retry: True (WaitingForOperation)`

4. Evidencia post-mitigacion:
   - `HEALTH_OK=12 HEALTH_ERR=0` tras reenrutar trafico.
   - Smoke test en verde (health/login/activities).
   - E2E productivo completo PASS con `execution_state=COMPLETADA`.

## Mitigaciones ya aplicadas

1. Deploy base con Firestore:
   - `sao-api-00055-n2r`

2. Ajuste temporal:
   - `sao-api-00056-r75`
   - `minScale=2`, `maxScale=20`, `concurrency=40`

3. Ajuste alterno para evitar warm-up bloqueado:
   - `sao-api-00057-54f`
   - `minScale=0`, `maxScale=10`, `concurrency=80`

4. Capacidad ampliada:
   - `sao-api-00058-jtw`
   - `minScale=1`, `maxScale=100`, `concurrency=200`

5. Intento final con baseline mayor (revision afectada):
   - `sao-api-00059-vgv`
   - `minScale=2`, `maxScale=100`, `concurrency=200`

6. Mitigacion efectiva:
   - Reenrutar trafico a revision estable (`sao-api-00058-jtw`) para recuperar disponibilidad.
   - Desacoplar Cloud SQL de Cloud Run (`sao-api-00061-ft5`).
   - Ajuste temporal de rate limit de login para corrida E2E final (`sao-api-00062-v8v`).

## Impacto

- Durante incidente: smoke/E2E bloqueados por disponibilidad de instancia.
- Estado actual: flujo principal validado end-to-end en produccion.

## Seguimiento

1. Mantener monitoreo de 429/5xx por 7 dias sobre revisiones nuevas.
2. Evitar enrutar 100% trafico a revisiones en `MinInstancesWarming`.
3. Mantener smoke post-deploy obligatorio antes de cierre de ventana.

## Comandos usados para evidencia

```powershell
gcloud run services describe sao-api --region us-central1 --format "yaml(status.latestReadyRevisionName,status.traffic,spec.template.metadata.annotations,spec.template.spec.containerConcurrency,spec.template.spec.containers[0].resources)"

gcloud run revisions describe sao-api-00059-vgv --region us-central1 --format "yaml(status.conditions,status.logUrl)"

gcloud logging read "resource.type=cloud_run_revision AND resource.labels.revision_name=sao-api-00059-vgv AND httpRequest.status=429" --limit 20 --format "table(timestamp,httpRequest.requestUrl,textPayload)"
```
