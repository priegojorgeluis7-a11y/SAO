# Wizard de Registro y Estructura de Catálogos (Estado Actual)

## Objetivo
Documentar cómo funciona hoy el flujo de registro de actividad (wizard), cómo se persiste localmente y cómo se resuelven/sincronizan los catálogos que alimentan los campos del formulario.

---

## 1) Flujo de acceso al registro (UI)

### Entradas al wizard
- Desde Home (botón flotante agregar): ruta `/wizard/register?project=<codigo_proyecto>`.
- Desde una actividad existente (swipe/detalle): ruta `/activity/:id/wizard?project=<codigo_proyecto>`.

### Rutas y construcción
- `core/routing/app_router.dart` define ambas rutas.
- `/wizard/register` crea una actividad nueva en memoria (`TodayActivity` temporal) y abre `RegisterWizardPage`.
- `/activity/:id/wizard` abre `ActivityWizardPage` con la actividad seleccionada (o placeholder si no viene `extra`).

### Máquina de estado en Home (ejecución)
En `home_page.dart` hay un flujo por swipe derecho:
1. `pendiente` → iniciar (marca hora inicio, pasa a `enCurso`).
2. `enCurso` → terminar y abrir wizard (marca hora fin, pasa a `revisionPendiente`).
3. `revisionPendiente` → reintentar captura (reabre wizard).
4. Si el wizard guarda, la actividad pasa a `terminada`.

Además, Home mantiene el FAB de agregar actividad y conserva el parámetro de proyecto en la navegación.

---

## 2) Wizard de registro (4 pasos)

`ActivityWizardPage` usa `PageView` no deslizante con 4 pasos:
1. Contexto (`WizardStepContext`)
2. Clasificación (`WizardStepFields`)
3. Evidencia (`WizardStepEvidence`)
4. Confirmación y guardado (`WizardStepConfirm`)

El estado central vive en `WizardController`.

### Paso 1: Contexto
Campos principales:
- Horario: hora inicio y hora fin.
- Ubicación administrativa: estado, municipio, colonia.
- PK editable: puntual, tramo o general.
- Riesgo: bajo, medio, alto, prioritario.

Validación reactiva del paso:
- `validateContextStep()` exige riesgo.
- UI muestra feedback háptico, snackbar y scroll al primer error.

### Paso 2: Clasificación
Campos principales:
- Actividad principal.
- Subcategoría (incluye opción “otro” con texto).
- Propósito (según actividad/subcategoría).
- Temas tratados (incluye “otro tema” con texto).
- Asistentes (institucionales y locales).
- Resultado final.

Validación reactiva del paso:
- `validateFieldsStep()` exige riesgo, actividad, subcategoría, propósito (si aplica), resultado y texto cuando se usa “otro”.
- UI hace scroll al primer campo inválido y muestra error.

### Paso 3: Evidencia
- Permite cámara, galería y botón PDF (PDF aún pendiente).
- Mantiene lista de evidencias con descripción por cada archivo.
- A nivel visual permite continuar sin evidencia (diálogo de confirmación).

### Paso 4: Confirmación y guardado
- Resume contexto, clasificación y evidencia.
- Permite editar cada bloque saltando al paso correspondiente.
- Botón Guardar ejecuta validación final estricta (Gatekeeper) y luego persistencia local.

---

## 3) Validación final estricta (Gatekeeper)

Antes de guardar, `validateBeforeSave()` aplica prioridades:
1. Debe haber al menos una evidencia.
2. Toda evidencia debe tener descripción.
3. Horas inicio/fin requeridas y fin > inicio.
4. Municipio y colonia obligatorios.
5. Riesgo obligatorio.
6. Actividad y subcategoría obligatorias.
7. Al menos un tema.
8. Al menos un asistente.
9. Resultado obligatorio.

Si falla:
- Muestra diálogo de error,
- Salta al paso correspondiente,
- No guarda.

Nota importante:
- Hay una diferencia entre la UX del paso 3 (que deja avanzar sin evidencia) y el Gatekeeper final (que sí exige evidencia para guardar).

---

## 4) Persistencia local del registro

### Guardado actual
`WizardController.saveToDatabase()`:
- Inserta en `activities` (tabla Drift).
- Inserta campos dinámicos en `activity_fields`.
- Usa `ActivityDao.upsertDraft()` para transacción y log.

### Tablas relevantes
- `activities`: cabecera de la actividad (id, project_id, type, título, descripción, PK, estado).
- `activity_fields`: pares campo/valor (texto, número, fecha, json).
- `activity_log`: bitácora de cambios.

### Mapeo actual de campos guardados
En `activity_fields` se guarda, entre otros:
- `risk_level`
- `activity_type`
- `subcategory`
- `subcategory_other_text`
- `purpose`
- `topics` (JSON array)
- `topic_other_text`
- `attendees` (JSON array)
- `result`
- `has_evidence`

### Observaciones de implementación vigente
- `currentUserId` en wizard se inicializa como placeholder `user-local`.
- En confirmación, el guardado usa placeholders para `projectId` y `activityTypeId`:
  - `project-uuid-example`
  - `activity-type-uuid`
- Esto indica que el flujo está funcional para captura local, pero aún requiere conexión final con contexto real de proyecto/tipo para producción completa del registro operativo.

---

## 5) Catálogos: arquitectura actual (backend → móvil)

## 5.1 Endpoints backend usados por móvil
En `backend/app/api/v1/catalog.py`:
- `GET /catalog/version/current?project_id=...`
  - Devuelve `version_id` actual.
- `GET /catalog/effective?project_id=...&version_id=...`
  - Devuelve snapshot efectivo completo.
- `GET /catalog/diff?project_id=...&from_version_id=...&to_version_id=...`
  - Devuelve cambios incrementales.

Respuestas modeladas en `backend/app/schemas/effective_catalog.py`.

## 5.2 Entidades del catálogo efectivo
Estructura principal del payload efectivo:
- `meta`
- `activities`
- `subcategories`
- `purposes`
- `topics`
- `rel_activity_topics`
- `results`
- `attendees`

Cada entidad incluye campos efectivos (por ejemplo `name_effective`, `is_enabled_effective`, `sort_order_effective`) derivados de base + overrides por proyecto/version.

## 5.3 Resolución efectiva en backend
`EffectiveCatalogService`:
- Resuelve versión actual desde `catalog_version.is_current=true`.
- Carga base de tablas efectivas (`cat_activities`, `cat_subcategories`, etc.).
- Aplica `proj_catalog_override` por `project_id` + `version_id`.
- Filtra entidades deshabilitadas y relaciones inválidas.
- Retorna catálogo efectivo final.

## 5.4 Seed vigente TMQ
`effective_catalog_tmq_v1.py` define:
- `VERSION_ID = tmq-v1.0.0`
- `PROJECT_ID = TMQ`
- Catálogos base para actividades, subcategorías, propósitos, temas, resultados y asistentes.

---

## 6) Sincronización de catálogos en frontend

## 6.1 Cliente y servicio de sync
- `core/catalog/api/catalog_api.dart`
- `core/catalog/sync/catalog_sync_service.dart`
- `core/catalog/state/catalog_sync_controller.dart`

Flujo:
1. Lee versión local en KV (`catalog_version:<projectId>`).
2. Consulta versión actual en backend.
3. Si no hay versión local: descarga `effective` y materializa snapshot.
4. Si cambió versión: intenta `diff`; si falla, hace fallback a `effective`.
5. Persiste nueva versión en KV.

## 6.2 Materialización local (Drift)
Tablas locales de catálogo efectivo:
- `cat_activities`
- `cat_subcategories`
- `cat_purposes`
- `cat_topics`
- `cat_rel_activity_topics`
- `cat_results`
- `cat_attendees`

`CatalogSyncService` mapea explícitamente campos efectivos del backend a estas tablas.

## 6.3 Bootstrap de catálogo
`CatalogBootstrapScreen`:
- Si hay sesión válida, dispara sync en background.
- No bloquea la navegación principal cuando auth ya está lista.

`CatalogSyncController`:
- Incluye guard `_isSyncing` para evitar syncs solapados.
- Diferencia errores de auth vs red/servidor.
- Permite fallback a catálogo local cuando aplica.

---

## 7) Cómo consume catálogos el wizard hoy

El wizard usa `CatalogRepository` (`features/catalog/catalog_repository.dart`) como fuente de listas para UI:
- Actividades, subcategorías, propósitos, temas, asistentes y resultados.
- Soporta estructura agrupada y estructura plana del payload para compatibilidad.
- Permite agregar ítems custom locales y candidatos pendientes de aprobación (persistidos en archivos locales).

Importante:
- Esta capa de repositorio está orientada a consumo UI y compatibilidad de formato.
- La sincronización efectiva (API + diff + snapshot) vive en la capa `core/catalog/*` y materializa en Drift.

---

## 8) Estado funcional resumido

- El flujo de wizard está operativo en navegación y captura.
- El botón de agregar actividad en Home está restaurado y enruta al wizard con proyecto.
- La sincronización de catálogos efectivos está integrada con versión actual, diff y fallback.
- El backend expone correctamente `version/current` y `effective` para el proyecto activo.

Pendientes funcionales detectados en código:
- Reemplazar placeholders de `currentUserId`, `projectId` y `activityTypeId` al guardar.
- Unificar la regla de evidencia entre paso 3 y Gatekeeper final (hoy están desalineadas).
- Conectar el botón PDF a implementación real en evidencia.
