# SAO - Documento Maestro del Sistema

**Fecha:** 2026-03-09  
**Alcance:** Vista ejecutiva y tecnica unificada del sistema SAO  
**Fuentes canonicas:** `STATUS.md`, `ARCHITECTURE.md`, `README.md`, `docs/README.md`

## 1. Resumen ejecutivo
SAO es una plataforma de administracion operativa para trabajo de campo con arquitectura offline-first, backend en FastAPI y clientes Flutter (movil y escritorio). El sistema esta orientado a operaciones multi-proyecto, control por roles (RBAC), sincronizacion incremental y trazabilidad completa.

## 2. Objetivo de negocio
- Estandarizar registro operativo en campo.
- Reducir perdida de informacion cuando no hay conectividad.
- Controlar calidad mediante flujo de revision y evidencia.
- Mantener gobierno de reglas por catalogos versionados.

## 3. Arquitectura del sistema
## 3.1 Componentes principales
- Backend API: FastAPI + PostgreSQL (Cloud SQL) + storage de evidencias.
- App operativa: Flutter con Drift (SQLite) y outbox de sincronizacion.
- App escritorio admin: Flutter Windows para revision, administracion y monitoreo.
- Infraestructura: Cloud Run, Artifact Registry, Cloud Build, GitHub Actions.

## 3.2 Principios de diseno
- Catalog-driven: formularios, workflow y reglas vienen de catalogos.
- Offline-first: captura local con sincronizacion posterior.
- RBAC + scope: seguridad por rol y alcance.
- Versionado y trazabilidad: cambios auditables extremo a extremo.

## 4. Modulos funcionales
- Autenticacion y sesion: login, refresh token, perfil.
- Actividades: alta, edicion, evidencia, envio y ciclo de revision.
- Eventos: registro de incidencias operativas.
- Catalogos: publicacion y consumo de versiones efectivas.
- Sync: push/pull incremental con control por cursor.
- Review y auditoria: cola de revision, decisiones y bitacora.

## 5. Flujo operativo de alto nivel
1. Operativo captura actividad localmente (offline o online).
2. Datos y evidencias se encolan en sincronizacion.
3. Backend recibe push y actualiza estado.
4. Coordinacion revisa y decide (aprobar/rechazar/solicitar cambios).
5. Cliente operativo recibe resultado por pull sync.

Referencias: `docs/WORKFLOW.md`, `docs/SYNC.md`, `docs/FLUJO_APP_AS_IS.md`, `docs/FLUJO_APP_TO_BE.md`.

## 6. Datos, contratos y versionado
- Contrato de catalogo: `docs/CATALOG_CONTRACT.md`.
- Modelo de actividad: `docs/ACTIVITY_MODEL_V1.md`.
- Politica de versiones: `docs/VERSIONING.md`.
- Mapa exacto de entidades y archivos: `docs/REPO_MAP.md`.

## 7. Operacion y despliegue
- Runbook productivo: `docs/RUNBOOK_CLOUD_RUN.md`.
- E2E staging: `docs/RUNBOOK_E2E_STAGING.md`.
- Guias de deploy: `docs/DEPLOYMENT_QUICKSTART.md`, `docs/DEPLOYMENT_EXECUTION_GUIDE.md`.
- CI/CD de cierre: `docs/CI_CD_CIERRE_CHECKLIST.md`.

## 8. Estado actual y calidad
- Estado general y bloqueos actuales: `STATUS.md`.
- Auditoria integral: `docs/AUDIT_REPORT.md`.
- Auditorias puntuales: `docs/historico/auditorias/AUDITORIA_MOVIL_2026-03-05.md`, `docs/historico/auditorias/CODE_AUDIT_2026-03-09.md`.
- Regresion funcional: `docs/CHECKLIST_REGRESION.md`.

## 9. Riesgos activos (resumen)
- Estabilizar cierre CI/CD completo con evidencia final en verde.
- Seguir elevando cobertura en modulos desktop fuera de auth.
- Reducir deuda documental historica y evitar duplicidad de fuentes.

## 10. Gobierno documental
Este documento es el punto de entrada maestro. Para mantener consistencia:
- Cambios de arquitectura: actualizar primero `ARCHITECTURE.md`.
- Cambios de estado/progreso: actualizar primero `STATUS.md`.
- Cambios de operacion/infra: actualizar runbooks y checklist CI/CD.
- Nuevos documentos: registrarlos en `docs/README.md`.

## 11. Indice maestro completo
Ver indice organizado y clasificado en `docs/README.md`.
