# Diagnostico de Cumplimiento - Flujo 100% Funcional
Fecha: 2026-03-05
Alcance: backend, mobile Flutter (`frontend_flutter/sao_windows`), desktop Flutter (`desktop_flutter/sao_desktop`)
Metodo: revision de implementacion + evidencia en codigo + estado de pruebas reportado en workspace.

## Resumen ejecutivo
- Cumplimiento parcial del flujo objetivo.
- Fortalezas actuales: catalogo versionado por proyecto en backend, endpoints de bundle/effective/diff/version current, sync push/pull con cursores, E2E staging en verde.
- P0 backend/mobile cerrado: `GET /me/projects` implementado y consumido en mobile, `GET /catalog/versions?project_ids=...` implementado en contrato dual, validacion de actividades anclada a `catalog_version_id` en `POST /activities` y `POST /sync/push`.
- Brechas criticas restantes para 100%: persistencia offline de catalogo en mobile sin indice/versionado historico robusto por proyecto-version y cierres de operacion/CI de plan final.

## Matriz de cumplimiento por requisito

### 1) Reglas base
1.1 Catalogo por proyecto independiente y versionado
- Estado: Parcial.
- Cumple:
  - Existe modelo versionado por proyecto (`CatalogVersion.project_id`, `version_number`).
  - Existen endpoints `/catalog/version/current`, `/catalog/bundle`, `/catalog/diff`.
- No cumple del todo:
  - Coexisten dos modelos/versionados (UUID en `catalog_versions` y texto semantico en `catalog_version` effective), con riesgo de ambiguedad operativa.

1.2 Actividad offline congela catalogo usado
- Estado: Parcial a insuficiente (mobile).
- Cumple:
  - DTO de sync incluye `catalog_version_id`.
  - Backend persiste `catalog_version_id` en actividad.
- Gap:
  - Modelo local principal de actividades en mobile no tiene columna explicita `catalog_version_id`.

1.3 Actualizar catalogo no reescribe capturas previas
- Estado: Parcial.
- Cumple:
  - En backend no hay migracion automatica de actividades al actualizar catalogo.
- Gap:
  - Mobile no implementa estrategia formal de retencion multi-version de bundles por actividades existentes.

### 2) Arquitectura de sync de catalogos (check ligero + bundle pesado)
2.1 Check ligero multiproyecto (`GET /catalog/versions?project_ids=...`)
- Estado: Cumple.
- Evidencia:
  - `GET /catalog/versions?project_ids=...` devuelve digest por proyecto en formato mapa.
  - Se preserva contrato historico por `project_id` (contrato dual).

2.2 Bundle pesado por proyecto/version
- Estado: Cumple parcialmente.
- Cumple:
  - `GET /catalog/bundle?project_id=...` implementado.
- Gap:
  - El contrato solicitado incluye `version_id` como parametro duro; en implementacion actual la resolucion es principalmente por version activa.

### 3) Flujo mobile offline-first
3.1 On login/refresh -> `GET /me/projects`
- Estado: Cumple.
- Evidencia:
  - Existe `GET /me/projects` en backend.
  - `ProjectsPage` en mobile consume `/me/projects` con fallback controlado a `/projects` y local.

3.2 Check on connectivity / app open con versions
- Estado: Parcial.
- Cumple:
  - Hay servicios de sync de catalogo y check updates.
- Gap:
  - Se usa `check-updates` por proyecto, no check ligero multiproyecto consolidado.

3.3 Almacenamiento local recomendado (`catalog_index`, `catalog_bundle` por version)
- Estado: No cumple totalmente.
- Implementado hoy:
  - Cache de bundle por proyecto en archivo (`catalog_bundle_<PROJECT>.json`).
  - Estado de version en `KvStore` por proyecto en algunos flujos.
- Gap:
  - No existe tabla robusta `catalog_index(project_id, active_version_id, hash, updated_at)`.
  - No existe repositorio historico por version (`catalog_bundle(project_id, version_id, json_blob, ...)`) con GC ligado a actividades.

### 4) Cambio de catalogo a media chamba
- Estado: Parcial.
- Cumple:
  - Hay pull diff/effective.
- Gap:
  - No hay mecanismo formal para conservar multiples versiones de bundle mientras existan actividades que las referencian.

### 5) Sync de actividades consistente con catalogos
- Estado: Cumple en P0.
- Evidencia:
  - Push de actividades incluye `catalog_version_id`.
  - Backend valida actividad contra el catalogo exacto (`catalog_version_id`) en `create_activity` y `sync_push`.
  - `sync/push` retorna `INVALID` con `error_code` y `message` por item cuando aplica.

### 6) Compatibilidad vs ruptura (IDs estables/semver)
- Estado: Parcial.
- Cumple:
  - Existen ids estables en entidades de catalogo (`activity_id`, `subcategory_id`, etc.).
- Gap:
  - No hay politica explicitamente exigida en runtime para breaking changes (`breaking_changes`, `schema_migrations`) en el contrato de bundle consumido por mobile.

### 7) Diff incremental opcional
- Estado: Cumple base.
- Evidencia:
  - `GET /catalog/diff` implementado.

### 8) Garantia de actualizacion de catalogo
- Estado: Parcial.
- Cumple:
  - Pull periodico/check-update esta implementado.
- Gap:
  - No hay push notification integrada para invalidacion de catalogo (FCM) + confirmacion pull.

### 9) UX operativo de estado de catalogo
- Estado: Parcial.
- Cumple:
  - Hay vistas/settings con smoke de catalogos.
- Gap:
  - No esta estandarizado en UX el estado solicitado por proyecto: `vX.Y.Z actualizado`, `update pendiente`, `offline`.

### 10) Checklist por capa
Backend
- Cumple P0: `/me/projects`, contrato dual de `/catalog/versions` y validacion fuerte por `catalog_version_id` ya aplicados.

Mobile
- Parcial: hay sync de catalogos, pero falta indice/versionado historico robusto + congelamiento verificable por actividad local.

Desktop
- Parcial: no se confirma badge sistemico en review/listados para "capturada con vX".

## Hallazgos operativos adicionales (del turno)
- Corregido: riesgo de atasco en sync de eventos offline editados antes del primer push.
- Corregido: enforcement de `requires_comment` en rechazo de revision.
- Corregido: endurecimiento CI backend (smoke autenticado y URL dinamica).
- Corregido: Flutter CI pasa de prueba puntual a suite completa.
- Corregido: script demo deja de hardcodear password.

## Conclusiones para llegar a 100%
1. P0 funcional de contratos y validacion catalogo-actividad: CERRADO.
2. Formalizar almacenamiento mobile por proyecto-version (indice + bundles versionados + GC seguro).
3. Exponer UX de estado de catalogo por proyecto en mobile y badge de version en desktop.
4. Completar cierres operativos/documentales del plan final (CI/CD en `main`, consolidacion de reportes de auditoria y estado).
