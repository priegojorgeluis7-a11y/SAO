# SAO — Firestore Index Inventory
**Versión:** 1.2.0 | **Fecha:** 2026-03-17
**Scope:** Producción (Cloud Firestore, modo nativo — `sao-prod-488416`)

---

## Propósito
Este documento lista todos los índices de Firestore requeridos por la API SAO.
Debe mantenerse sincronizado con `firestore.indexes.json` y los queries de los módulos
`activities.py`, `audit.py`, `catalog.py`, `projects.py`, `territory.py`,
`assignments.py`, `review.py`, `sync.py` y `firestore_identity_service.py`.

El archivo fuente de verdad es `firestore.indexes.json` en la raíz del proyecto.
Para desplegar cambios:
```bash
firebase deploy --only firestore:indexes
```

---

## Índices Compuestos Activos

Firestore crea índices de un solo campo automáticamente.
Las consultas con `.where()` + `.order_by()` sobre campos distintos requieren un índice compuesto.

| # | Colección | Campo 1 | Campo 2 | Campo 3 | Usado en |
|---|-----------|---------|---------|---------|----------|
| 1 | `catalog_versions` | `project_id` (ASC) | `is_current` (ASC) | — | `catalog.py`: `_resolve_current_version_id_firestore`, `_latest_catalog_doc_firestore`, `_catalog_versions_firestore`; `territory.py`; `projects.py` |
| 2 | `catalog_versions` | `project_id` (ASC) | `published_at` (DESC) | — | `catalog.py`: `_latest_catalog_doc_firestore` (fallback por fecha) |
| 3 | `audit_logs` | `entity` (ASC) | `entity_id` (ASC) | `created_at` (DESC) | Reservado para queries combinados entity + entity_id |
| 4 | `audit_logs` | `entity_id` (ASC) | `created_at` (DESC) | — | `activities.py:get_activity_timeline` — `.where(entity_id).order_by(created_at DESC).limit(50)` |
| 5 | `activities` | `project_id` (ASC) | `updated_at` (DESC) | — | `activities.py:_list_activities_firestore` — `.where(project_id).order_by(updated_at DESC)` |

Todos desplegados en producción el 2026-03-17.

---

## Índices de Campo Único (auto-gestionados por Firestore)

No requieren configuración manual.

| Colección | Campo | Tipo de consulta | Usado en |
|-----------|-------|-----------------|----------|
| `activities` | `project_id` | equality | `assignments.py`, `sync.py`, `activities.py` |
| `activities` | `front_id` | equality + `.limit(1)` | `projects.py` |
| `audit_logs` | `entity_id` | equality | `activities.py:get_activity_timeline` (filtro base) |
| `catalog_versions` | `project_id` | equality | `catalog.py` |
| `catalog_versions` | `is_current` | equality | `catalog.py` (fallback global) |
| `fronts` | `project_id` | equality | `territory.py`, `projects.py`, `review.py` |
| `users` | `email` | equality | `firestore_identity_service.py` |
| `dashboard` | `project_id` | equality | `dashboard.py` |

---

## Colecciones — Acceso Solo por ID de Documento

Lookups por `.document(id).get()` — sin índice requerido.

| Colección | Patrón de ID | Usado en |
|-----------|-------------|----------|
| `activities` | UUID de actividad | `sync.py`, `review.py` |
| `catalog_current` | `{PROJECT_ID}` | `catalog.py` |
| `catalog_effective` | `{PROJECT_ID}:{version_id}` o `{PROJECT_ID}` | `catalog.py`, `sync.py` |
| `catalog_bundles` | `{PROJECT_ID}:{version_id}` o `{PROJECT_ID}` | `catalog.py`, `sync.py` |
| `catalog_versions` | UUID de versión | `catalog.py` |
| `evidences` | UUID de evidencia | `review.py` |
| `fronts` | UUID de frente | `review.py` |
| `rate_limits` | `{window_start}:{sha256(scope+client+window)}` | `core/rate_limit.py` |

---

## Colecciones — Escaneo Completo Pendiente de Optimizar

Aceptable mientras el volumen sea bajo (< 5 000 docs por colección).

| Colección | Ruta de código | Acción recomendada si crece |
|-----------|---------------|---------------------------|
| `evidences` | `review.py` (varias rutas) | Agregar `.where("activity_id", "==", X)` + índice `activity_id ASC` |
| `users` | `review.py` (construct review queue) | Tolerable; tabla usuarios pequeña |

---

## Escrituras (sin índice requerido)

| Colección | Operación | Usado en |
|-----------|-----------|----------|
| `activities` | `.document(uuid).set(..., merge=True)` | `sync.py` |
| `audit_logs` | `.document(uuid4).set(...)` | `review.py`, `audit_service.py` |
| `evidences` | `.document(uuid).set(...)` | `review.py` |
| `review_evidence_actions` | `.document(uuid4).set(...)` | `review.py` |
| `catalog_bundles` | `.document(project).set(...)` | `catalog.py` |
| `catalog_current` | `.document(project).set(...)` | `catalog.py` |
| `catalog_versions` | `.document(version_id).set(...)` | `catalog.py` |
| `rate_limits` | `.document(window+hash).set(..., merge=True)` | `core/rate_limit.py` |

---

## Historial de cambios

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.0.0 | 2026-03-10 | Inventario inicial |
| 1.1.0 | 2026-03-17 | +2 índices desplegados: `activities(project_id+updated_at)` y `audit_logs(entity_id+created_at)`; limpieza de secciones obsoletas |
| 1.2.0 | 2026-03-17 | Documentada colección `rate_limits` usada por rate limiting distribuido (sin nuevos índices compuestos requeridos) |
