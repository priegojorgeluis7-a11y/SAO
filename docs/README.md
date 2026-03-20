# SAO - Centro de Documentacion

## Objetivo
Este documento organiza toda la documentacion del repositorio en un unico punto de entrada.

## Ruta recomendada de lectura
1. `docs/DOCUMENTO_MAESTRO_EJECUCION_SAO.md`
2. `docs/DOCUMENTO_MAESTRO_SISTEMA.md`
3. `STATUS.md`
4. `README.md`
5. `ARCHITECTURE.md`

## Documento maestro de ejecucion
- `docs/DOCUMENTO_MAESTRO_EJECUCION_SAO.md` - historia completa de implementacion, procedimientos operativos y playbooks de incidentes.

## 1) Gobierno y estado
- `STATUS.md` - estado operativo, avances y bloqueos.
- `CHANGELOG.md` - historial de cambios por version.
- `VERSION` - version actual del sistema.
- `docs/AUDIT_REPORT.md` - hallazgos y estado de auditoria.
- `docs/PRODUCTION_READINESS_CHECKLIST.md` - checklist de salida a produccion.
- `docs/PLAN_CIERRE_100_FUNCIONAL.md` - plan de cierre funcional.

## 2) Arquitectura y diseno
- `ARCHITECTURE.md` - referencia arquitectonica integral.
- `docs/REPO_MAP.md` - mapa tecnico del repositorio.
- `docs/SERVICES_MATRIX.md` - matriz de servicios y responsabilidades.
- `docs/FUNCIONES_SISTEMA.md` - funciones principales por modulo.
- `docs/DESIGN_SYSTEM.md` - lineamientos de UI.
- `docs/DESIGN_TOKENS.md` - tokens visuales.

## 3) Dominio funcional y flujos
- `docs/FLUJO_APP_AS_IS.md` - flujo actual.
- `docs/FLUJO_APP_TO_BE.md` - flujo objetivo.
- `docs/WORKFLOW.md` - estados y transiciones de actividades.
- `docs/SYNC.md` - sincronizacion y comportamiento offline.
- `docs/ACTIVITY_MODEL_V1.md` - modelo de actividad.
- `docs/VISION_TUTORIAL_APP.md` - vision y guia de uso.
- `docs/WIZARD_REGISTRO_Y_CATALOGOS_ACTUALES.md` - wizard y catalogos.

## 4) Catalogos y contratos
- `docs/CATALOG_CONTRACT.md` - contrato del bundle de catalogo.
- `docs/VERSIONING.md` - estrategia de versionado.

## 5) Operacion, despliegue e infraestructura
- `docs/RUNBOOK_CLOUD_RUN.md` - operacion en Cloud Run.
- `docs/RUNBOOK_E2E_STAGING.md` - guia E2E en staging.
- `docs/DEPLOYMENT_QUICKSTART.md` - despliegue rapido.
- `docs/DEPLOYMENT_EXECUTION_GUIDE.md` - ejecucion de despliegue.
- `docs/CI_CD_CIERRE_CHECKLIST.md` - checklist de cierre CI/CD.
- `docs/GCP_INTEGRATION_SAO.md` - integracion GCP.
- `docs/CLOUD_SQL_INTEGRATION_GUIDE.md` - integracion Cloud SQL.
- `docs/CLOUD_SQL_QUICK_REFERENCE.md` - referencia rapida Cloud SQL.

## 6) Calidad, auditoria y analisis
- `docs/CHECKLIST_REGRESION.md` - regresion funcional.
- `docs/UI_VISUAL_RULES.md` - reglas visuales.

## 7) Planes de trabajo e implementacion
- `IMPLEMENTATION_PLAN.md` - plan de implementacion transversal.
- `docs/PLAN_100_LOCAL.md` - plan operativo 100% local.
- `docs/PLAN_GAPS_PRIORIDAD_MEDIA.md` - cierre de gaps prioridad media.
- `docs/PLAN_MIGRACION_FIRESTORE.md` - plan de migracion de Cloud SQL a Firestore con estimacion de costos.

## 8) Historico (auditorias y diagnosticos fechados)
- Indice historico: `docs/historico/README.md`
- `docs/historico/auditorias/AUDITORIA_MOVIL_2026-03-05.md` - auditoria de app movil.
- `docs/historico/auditorias/AUDITORIA_FIX_CATALOGOS_MULTIPROYECTO.md` - auditoria de fix multi-proyecto.
- `docs/historico/auditorias/CODE_AUDIT_2026-03-09.md` - auditoria de malas practicas.
- `docs/historico/auditorias/UI_VISUAL_AUDIT_2026-03-02.md` - auditoria visual.
- `docs/historico/auditorias/SETTINGS_VIEW_REVIEW_2026-03-09.md` - revision de pantalla de settings.
- `docs/historico/planes/PLAN_FIX_HALLAZGOS_SEVERIDAD_2026-03-05.md` - plan de mitigacion por severidad.
- `docs/historico/planes/DIAGNOSTICO_FLUJO_100_FUNCIONAL_2026-03-05.md` - diagnostico funcional.

## 9) Documentacion de soporte
- `docs/AGENT_CONTEXT.md` - contexto para agentes/automatizacion.

## Convenciones para mantener ordenada la documentacion
- Usar prefijos por dominio cuando se creen nuevos documentos: `RUNBOOK_`, `PLAN_`, `AUDITORIA_`, `CHECKLIST_`, `GUIDE_`.
- Incluir siempre cabecera con: fecha, version/alcance, estado.
- Evitar duplicar contenido de arquitectura; enlazar en su lugar al documento canonico.
- Si un documento queda obsoleto, moverlo a seccion historica o marcarlo como superseded.
- Usar `docs/TEMPLATE_DOC.md` como base para nuevos documentos.
