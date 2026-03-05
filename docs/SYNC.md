# SAO — Sync Architecture
**Versión:** 1.0.0 | **Fecha:** 2026-03-04

---

## 1. Visión General

```
MOBILE (Offline-First)              BACKEND (Source of Truth)
─────────────────────               ──────────────────────────
   [Formulario]
       │
       ▼
   Drift SyncQueue ──PUSH──► POST /sync/push ──► PostgreSQL
   (PENDING/ERROR)                                    │
                                                      │
   Drift Activities ◄──PULL──── POST /sync/pull ◄────┘
   (actualizado)          [cursor since_version]
       │
       ▼
   Evidences Queue ──PRESIGN──► POST /evidences/upload-init
       │                                    │ signed_url
       └──UPLOAD────────────────────────────►GCS
       └──CONFIRM──► POST /evidences/upload-complete
```

---

## 2. Outbox Queue (Mobile)

### 2.1 Tabla `SyncQueue` (Drift)

```dart
class SyncQueue extends Table {
  TextColumn get id        => text()();          // UUID
  TextColumn get entity    => text()();          // 'ACTIVITY' | 'EVENT' | 'EVIDENCE'
  TextColumn get entityId  => text()();          // UUID de la entidad
  TextColumn get action    => text()();          // 'UPSERT' | 'DELETE'
  TextColumn get payloadJson => text()();        // JSON serializado
  IntColumn  get priority  => integer()();       // 0 = alta, 9 = baja
  IntColumn  get attempts  => integer()();
  TextColumn get status    => text()();          // PENDING | IN_PROGRESS | DONE | ERROR
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}
```

### 2.2 Flujo de encolado

1. Usuario completa formulario → Activity guardada en Drift con `status = DRAFT`.
2. Usuario presiona "Enviar" → Activity pasa a `READY_TO_SYNC` y se encola en `SyncQueue` (action=UPSERT, status=PENDING).
3. `AutoSyncService` detecta conectividad o dispara por timer → llama `SyncService.pushPendingChanges()`.

---

## 3. Push Sync (Mobile → Backend)

### 3.1 Implementación actual

**Archivo:** `lib/features/sync/services/sync_service.dart`

```
pushPendingChanges():
  1. Query SyncQueue WHERE entity='ACTIVITY' AND status IN ('PENDING','ERROR')
  2. Deserializar payloadJson → ActivityDTO
  3. Agrupar por project_id
  4. Por cada grupo: POST /sync/push { project_id, activities: [...] }
  5. Procesar respuesta por ítem:
     CREATED   → SyncQueue.status = DONE, Activity.status = SYNCED
     UPDATED   → SyncQueue.status = DONE, Activity.status = SYNCED
     UNCHANGED → SyncQueue.status = DONE
     CONFLICT  → SyncQueue.status = ERROR, Activity.status = ERROR
  6. Push EVENTs: POST /api/v1/events/{uuid} (idempotente por UUID)
  7. Actualizar SyncState.lastSyncAt
```

### 3.2 Endpoint backend

```
POST /api/v1/sync/push
Authorization: Bearer {token}

{
  "project_id": "TMQ",
  "activities": [
    {
      "uuid": "...",
      "project_id": "TMQ",
      "execution_state": "EN_CURSO",
      "pk_start": 123.5,
      "pk_end": 124.0,
      "sync_version": 0,
      ...
    }
  ]
}

Response:
{
  "results": [
    { "uuid": "...", "status": "CREATED", "server_id": 42, "sync_version": 1 },
    { "uuid": "...", "status": "CONFLICT", "conflict_version": 2 }
  ],
  "current_version": 7
}
```

### 3.3 Lógica de idempotencia (backend)

- Si `uuid` ya existe: compara `sync_version` del cliente vs servidor.
  - `client_version >= server_version` → UPDATE → `UPDATED`
  - `client_version < server_version` → Retorna `CONFLICT` (servidor tiene versión más nueva)
- Si `uuid` no existe → INSERT → `CREATED`

---

## 4. Pull Sync (Backend → Mobile)

### 4.1 Estado actual: PARCIALMENTE IMPLEMENTADO

El orquestrador `sync_orchestrator.dart` existe pero el pull real desde backend no está implementado.

### 4.2 Diseño target

```
POST /api/v1/sync/pull
{
  "project_id": "TMQ",
  "since_version": 5,      // cursor: última versión conocida
  "limit": 100             // paginación
}

Response:
{
  "activities": [...],     // activities con sync_version > since_version
  "current_version": 12,
  "has_more": false
}
```

### 4.3 Implementación pendiente (mobile)

```dart
// En SyncService o SyncOrchestrator:
Future<void> pullChanges(String projectId) async {
  final sinceVersion = await _db.syncMetadata.getSinceVersion(projectId);
  final response = await _syncApiRepo.pull(projectId, sinceVersion);

  for (final activity in response.activities) {
    await _db.activities.upsertFromServer(activity);
  }

  await _db.syncMetadata.saveSinceVersion(projectId, response.currentVersion);

  if (response.hasMore) {
    await pullChanges(projectId); // next page
  }
}
```

---

## 5. Evidencias (Upload Flow)

### 5.1 Tabla `PendingUploads` (Drift)

```dart
class PendingUploads extends Table {
  TextColumn get id          => text()();    // UUID
  TextColumn get activityId  => text()();
  TextColumn get localPath   => text()();    // ruta local del archivo
  TextColumn get fileName    => text()();
  TextColumn get mimeType    => text()();
  IntColumn  get sizeBytes   => integer()();
  TextColumn get evidenceId  => text().nullable()();  // asignado tras upload-init
  TextColumn get objectPath  => text().nullable()();  // ruta en GCS
  TextColumn get signedUrl   => text().nullable()();  // pre-signed URL (15min)
  TextColumn get status      => text()();    // PENDING_INIT | PENDING_UPLOAD | PENDING_COMPLETE | DONE | ERROR
  IntColumn  get attempts    => integer()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
}
```

### 5.2 Flujo de 3 pasos

```
[1] PENDING_INIT
POST /evidences/upload-init
  { activity_id, file_name, mime_type, size_bytes }
Response: { evidence_id, signed_url, object_path }
  → Guarda evidence_id, signed_url, object_path
  → Status: PENDING_UPLOAD

[2] PENDING_UPLOAD
PUT {signed_url} (binario directo a GCS)
  → Status: PENDING_COMPLETE

[3] PENDING_COMPLETE
POST /evidences/upload-complete
  { evidence_id, object_path }
Response: { success: true }
  → Status: DONE
```

### 5.3 Retry logic

- `attempts` se incrementa en cada fallo.
- `nextRetryAt = now + backoff(attempts)` — backoff exponencial.
- Máx intentos: 5 (configurable).
- Signed URLs expiran en 15 minutos → si `nextRetryAt > signed_url_expiry`, reiniciar desde PENDING_INIT.

---

## 6. Sync de Catálogo

### 6.1 Estado actual

- Mobile descarga bundle completo en `loadProjectBundle()`.
- No usa `GET /catalog/diff` incremental.

### 6.2 Diseño target (diff incremental)

```dart
Future<void> syncCatalog(String projectId) async {
  final localHash = await _db.catalogVersions.getHash(projectId);
  final check = await _apiClient.get('/catalog/check-updates?hash=$localHash');

  if (!check.updateAvailable) return; // ya actualizado

  if (check.diffAvailable) {
    // Descarga solo los cambios
    final diff = await _apiClient.get('/catalog/diff?from=$localHash');
    await _db.catalog.applyDiff(diff);
  } else {
    // Descarga bundle completo
    final bundle = await _apiClient.get('/catalog/bundle?project_id=$projectId');
    await _db.catalog.replaceBundle(bundle);
  }
}
```

---

## 7. Auto-Sync Service

**Archivo:** `lib/features/sync/services/auto_sync_service.dart`

```
AutoSyncService:
  onInit():
    ├── subscribeToConnectivity()
    │     ↳ si online: trigger sync inmediato
    └── Timer.periodic(Duration(minutes: 15))
          ↳ cada 15 min: pushPendingChanges() + pullChanges()

onConnectivityChange(status):
  if (status == online && wasOffline):
    await pushPendingChanges()
    await pullChanges()
    await syncPendingUploads()
```

---

## 8. Manejo de Conflictos

### 8.1 Estado actual (mobile)

- Backend retorna `CONFLICT` en push.
- Mobile marca la actividad con `status = ERROR` en Drift.
- **No hay UI de resolución.** El usuario no sabe qué hacer.

### 8.2 Diseño target

**Política:** Last-Write-Wins con confirmación del usuario en conflictos explícitos.

```
Conflicto detectado:
  → Mostrar dialog: "Esta actividad fue modificada por otro usuario"
  → Opciones:
     [Usar mi versión]  → reenviar con force_override=true
     [Usar versión del servidor] → descartar cambios locales, pull de esa actividad
     [Ver diferencias] → diff screen (opcional, fase avanzada)
```

**Endpoint adicional necesario:**
```
POST /sync/push
{
  "activities": [...],
  "conflict_resolution": "force" | "skip"
}
```

---

## 9. Métricas de Sync

El `SyncCenterPage` (mobile) debe mostrar:

| Métrica | Fuente |
|---------|--------|
| Último sync exitoso | `SyncState.lastSyncAt` |
| Items pendientes | `COUNT(SyncQueue WHERE status=PENDING)` |
| Uploads pendientes | `COUNT(PendingUploads WHERE status!=DONE)` |
| Items en error | `COUNT(SyncQueue WHERE status=ERROR)` |
| Conflictos activos | `COUNT(Activities WHERE status=ERROR)` |

---

## 10. Gaps y Deuda Técnica

| Gap | Prioridad | Plan |
|-----|-----------|------|
| Pull sync no implementado | ALTA | F3 del plan de implementación |
| Conflictos sin UI de resolución | ALTA | F3 |
| Pull incremental de eventos | MEDIA | F3 |
| Diff incremental de catálogo | MEDIA | F3 |
| Desktop sin outbox (sin offline) | ALTA | F3 |
| Retry backoff no configurable | BAJA | F5 |
