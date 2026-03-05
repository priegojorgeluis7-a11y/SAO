# SAO — Catalog Contract
**Versión:** 1.0.0 | **Fecha:** 2026-03-04

El catálogo es la **única fuente de verdad** para: tipos de actividad, subcategorías, propósitos, temas, resultados, reglas de workflow, colores semánticos y validaciones de formulario.

---

## 1. Schema del Bundle (`sao.catalog.bundle.v1`)

```jsonc
{
  "schema": "sao.catalog.bundle.v1",
  "meta": {
    "project_id": "TMQ",
    "bundle_id": "uuid-...",
    "generated_at": "2026-03-04T00:00:00Z",
    "versions": {
      "effective": "1.0.0",
      "editor_layer": "1.0.0-draft"
    }
  },
  "effective": {
    "entities": {
      "activities": [
        {
          "id": "CAM",
          "name": "Caminamiento",
          "description": "Recorrido de verificación de DDV",
          "active": true,
          "order": 0,
          "color_token": "activity.cam",    // token semántico (ver DESIGN_TOKENS.md)
          "icon": "walk",
          "requires_evidence": true,
          "requires_gps": true,
          "workflow_checklist": ["photo_min_1", "gps_point"]
        }
        // ... CAM, REU, ASP, CIN, SOC, AIN
      ],
      "subcategories": [
        {
          "id": "CAM_DDV",
          "activity_id": "CAM",
          "name": "Verificación de DDV",
          "active": true,
          "order": 0
        }
        // ... 23 subcats total
      ],
      "purposes": [
        {
          "id": "AFEC_VER_CAM",
          "activity_id": "CAM",
          "subcategory_id": "CAM_DDV",  // null → aplica a toda la actividad
          "name": "Verificación de afectaciones",
          "active": true
        }
      ],
      "topics": [
        {
          "id": "TOP_GAL",
          "name": "Gálibos",
          "type": "Técnico",
          "active": true,
          "order": 0
        }
        // 7 temas: TOP_GAL, TOP_ACC, TOP_TEN, TOP_AVA, TOP_ARB, TOP_INAH, TOP_CONS
      ],
      "results": [
        {
          "id": "RES_OK",
          "name": "Ejecución exitosa",
          "category": "Ejecución regular",
          "severity": "LOW",
          "active": true
        }
        // 12 tipos total
      ],
      "assistants": [
        { "id": "AST_ARTF", "name": "ARTF", "type": "Institucional" },
        { "id": "AST_SEDATU", "name": "SEDATU", "type": "Gubernamental" },
        { "id": "AST_SEDENA", "name": "SEDENA", "type": "Gubernamental" }
      ]
    },
    "relations": {
      "activity_to_topics_suggested": [
        { "activity_id": "CAM", "topic_ids": ["TOP_GAL", "TOP_ACC"] }
      ]
    },
    "rules": {
      "cascades": {
        "subcategories_by_activity": true,
        "purposes_by_activity_and_subcategory": true
      },
      "constraints": [
        { "type": "PARENT_INACTIVE_BLOCKS_CHILD_CREATE" }
      ],
      "topicPolicy": {
        "defaultMode": "any",
        "byActivity": {
          "CIN": { "mode": "required", "min": 1 }
        }
      },
      "workflow": {
        // FUTURO: máquina de estados debe venir aquí
        // Actualmente hardcoded en status_catalog.dart — DEUDA
        "states": ["borrador","nuevo","en_revision","requiere_cambios","aprobado","rechazado","sincronizado"],
        "transitions": [
          { "from": "borrador", "to": ["nuevo","en_revision"], "roles": ["OPERATIVO","COORD","SUPERVISOR","ADMIN"] },
          { "from": "nuevo", "to": ["en_revision","rechazado"], "roles": ["COORD","SUPERVISOR","ADMIN"] },
          { "from": "en_revision", "to": ["aprobado","rechazado","requiere_cambios"], "roles": ["COORD","SUPERVISOR","ADMIN"] },
          { "from": "requiere_cambios", "to": ["en_revision","rechazado"], "roles": ["COORD","SUPERVISOR","ADMIN"] },
          { "from": "aprobado", "to": ["sincronizado"], "roles": ["SYSTEM"] }
        ]
      }
    },
    "form_fields": {
      // Campos dinámicos por tipo de actividad
      // Derivados de CatalogFields en backend
      "CAM": [
        { "key": "asistentes", "label": "Asistentes", "type": "number", "required": true, "order": 0 },
        { "key": "pk_inicio", "label": "PK Inicio", "type": "text", "required": true, "order": 1 }
      ]
    },
    "color_tokens": {
      // Mapa de tokens semánticos a valores hex
      // Ver DESIGN_TOKENS.md para reglas de uso
      "activity.cam": "#16A34A",
      "activity.reu": "#3B82F6",
      "activity.asp": "#8B5CF6",
      "activity.cin": "#F59E0B",
      "activity.soc": "#EF4444",
      "activity.ain": "#6B7280",
      "risk.low": "#16A34A",
      "risk.medium": "#F59E0B",
      "risk.high": "#F97316",
      "risk.critical": "#DC2626",
      "status.borrador": "#9CA3AF",
      "status.nuevo": "#60A5FA",
      "status.en_revision": "#F59E0B",
      "status.requiere_cambios": "#F97316",
      "status.aprobado": "#16A34A",
      "status.rechazado": "#DC2626",
      "status.sincronizado": "#6366F1"
    }
  },
  "editor": {
    "layers": [],      // Overrides pendientes de publicar
    "validation": {},
    "history": []
  }
}
```

---

## 2. Versionado del Catálogo

### 2.1 Estados de versión

```
DRAFT → PUBLISHED → DEPRECATED
  ↑                     ↓
  └──── rollback ────────┘
```

- Solo una versión puede estar `PUBLISHED` por proyecto a la vez.
- `DEPRECATED` es terminal (no se puede reactivar).
- Rollback crea una nueva versión DRAFT copiando contenido de una versión anterior.

### 2.2 Identificación de versiones

```
{project_id}::{version_number}  →  TMQ::1.0.0
```

- `version_number` sigue semver (`MAJOR.MINOR.PATCH`).
- Cada versión tiene `hash` SHA256 del contenido efectivo.
- Los clientes usan el hash para verificar si tienen la versión actual.

### 2.3 Endpoints de ciclo de vida

| Operación | Endpoint | Rol requerido |
|-----------|----------|---------------|
| Obtener bundle actual | `GET /catalog/bundle?project_id=TMQ` | Cualquier usuario autenticado |
| Verificar actualizaciones | `GET /catalog/check-updates?project_id=TMQ&hash=abc123` | Autenticado |
| Diff incremental | `GET /catalog/diff?from=1.0.0&to=1.1.0` | Autenticado |
| Listar versiones | `GET /catalog/versions?project_id=TMQ` | ADMIN/SUPERVISOR |
| Ver versión | `GET /catalog/versions/{version_id}` | ADMIN/SUPERVISOR |
| Validar draft | `POST /catalog/validate` | `catalog.edit` |
| Publicar | `POST /catalog/publish` | `catalog.publish` |
| Rollback | `POST /catalog/rollback` | `catalog.publish` |
| Editor CRUD | `POST/PATCH/DELETE /catalog/editor/*` | `catalog.edit` |

---

## 3. Overrides por Proyecto

Los proyectos pueden tener overrides sobre el catálogo base (TMQ) via `PATCH /catalog/project-ops`.

**Uso:** TAP, TSNL, QIR parten del template TMQ pero pueden desactivar subcategorías, agregar propósitos o cambiar textos.

**Prioridad de resolución:**
```
Catálogo base TMQ < Project overrides → effective catalog (bundle)
```

---

## 4. Integración en Clientes

### 4.1 Regla de uso en Mobile

```dart
// ✅ CORRECTO: leer del bundle
final activities = ref.read(catalogRepositoryProvider).data.activities;
final color = ref.read(catalogRepositoryProvider).colorToken('activity.cam');

// ❌ PROHIBIDO: hardcode
final color = Color(0xFF16A34A);
final activities = ['CAM', 'REU', 'ASP'];
```

### 4.2 Cascade dropdowns

```
Selección actividad → filtrar subcategorías por activity_id
Selección subcategoría → filtrar propósitos por (activity_id, subcategory_id)
Sugerir temas → leer activity_to_topics_suggested[activity_id]
```

### 4.3 Validación de formulario

Todos los campos requeridos y sus tipos deben derivarse de `form_fields[activity_type_id]` del bundle, no de lógica hardcoded en widgets.

### 4.4 Colores y estados

Ver [DESIGN_TOKENS.md](DESIGN_TOKENS.md). Resumen:
- Colores de actividad → `catalog.colorToken('activity.{id}')`
- Colores de riesgo → `SaoColors.getRiskColor(level)` (que internamente usa tokens)
- Colores de estado → `SaoColors.getStatusColor(status)` (que internamente usa tokens)

---

## 5. Validaciones Requeridas antes de Publicar

El endpoint `POST /catalog/validate` verifica:
- Todos los `activity_id` en subcategorías existen en activities.
- Todos los `subcategory_id` en purposes existen en subcategories.
- No hay IDs duplicados dentro de una entidad.
- No hay referencias circulares en topics.
- `form_fields` tienen `key` único por `activity_id`.
- Todos los `color_token` tienen valor hex válido.

---

## 6. Assumptions (decisiones tomadas con defaults razonables)

| Assumption | Razón | Revisable |
|------------|-------|-----------|
| `form_fields` incluidos en bundle (no endpoint separado) | Reduce round-trips; simplifica offline | Sí |
| `color_tokens` incluidos en bundle | Permite actualizar branding sin redeploy de app | Sí |
| `workflow.transitions` incluidas en bundle | Permite ajustar workflow sin redeploy | Sí, requiere backend endpoint `GET /catalog/workflow` |
| Catalog diff basado en hash completo del bundle | Implementación más simple; suficiente para volumen actual | Sí, puede hacerse field-level diff |
