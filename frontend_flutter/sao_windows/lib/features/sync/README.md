# Centro de Sincronización (Sync Hub)

## 📋 Descripción General

El **Centro de Sincronización** es el "cuarto de máquinas" de SAO. Proporciona visibilidad y control completo sobre el estado de sincronización offline-online de la aplicación, diseñado para dar tranquilidad mental a usuarios en campo con conectividad inestable.

### Filosofía de Diseño

> "Para un usuario en campo, esta pantalla es sinónimo de tranquilidad mental. Debe responder instantáneamente: ¿Mi trabajo está seguro? ¿Se subió? ¿Puedo seguir trabajando offline?"

## 🎨 UX/UI Implementada

### Estructura Jerárquica (3 Bloques)

#### 1. Encabezado de Estado Global (Health Header)
- **Visualización**: Icono de nube animado con transiciones suaves
- **Estados**:
  - 🟢 **Verde** → `allSynced` - "Todo al día"
  - 🟠 **Azul** → `syncing` - "Sincronizando X elementos..."
  - 🔴 **Rojo** → `error` - "Error en X elementos" / "Sin conexión"
- **Acción Principal**: Botón gigante "Sincronizar Ahora" (UX: placebo de control)

#### 2. Cola de Subida (Upload Queue)
- **Lista de Pendientes**: Actividades, incidencias, evidencias esperando subir
- **Progress Bars**: Indicador de progreso para items en proceso de subida
- **Badges de Estado**:
  - 🕐 Esperando (amarillo)
  - 🔄 Subiendo X% (azul con progress)
  - ❌ Error (rojo con botón reintentar)
- **Estado Vacío**: "No hay elementos pendientes" con checkmark verde

#### 3. Recursos del Proyecto (Download Management)
- **Almacenamiento**: Barra de progreso visual (150 MB / 2 GB)
- **Recursos Disponibles**:
  - Planos Constructivos (45 MB)
  - Catálogo de Conceptos (12 MB)
- **Configuración**:
  - Toggle "Solo con WiFi"
  - Toggle "Descargar Planos"
  - Botón "Liberar espacio en dispositivo"

## 📁 Arquitectura de Archivos

```
lib/features/sync/
├── sync_center_page.dart        # UI Principal (ConsumerStatefulWidget)
├── models/
│   └── sync_models.dart         # Data models (SyncHealth, UploadQueueItem, etc.)
├── data/
│   ├── sync_repository.dart     # Repository para Drift DB
│   └── sync_provider.dart       # Riverpod providers
└── README.md                    # Este archivo
```

## 🏗️ Modelos de Datos

### SyncHealth
```dart
class SyncHealth {
  final SyncHealthStatus status;    // allSynced | syncing | error
  final String message;             // "Todo al día", "Sincronizando 3 elementos..."
  final DateTime? lastSyncAt;       // Última sincronización exitosa
  final int pendingCount;           // Elementos pendientes
  final int syncingCount;           // Elementos en progreso
  final int errorCount;             // Elementos con error
}
```

### UploadQueueItem
```dart
class UploadQueueItem {
  final String id;
  final UploadItemType type;        // activity | event | evidence
  final String title;               // "Actividad #abc12345"
  final String subtitle;            // "Hace 2h", timestamp relativo
  final UploadItemStatus status;    // pending | uploading | error
  final double? progress;           // 0.0-1.0 para progress bar
  final String? errorMessage;       // Mensaje de error detallado
  final int retryCount;             // Número de reintentos
}
```

### DownloadResource
```dart
class DownloadResource {
  final DownloadResourceType type;  // planos | catalogo
  final String name;                // "Planos Constructivos"
  final int sizeMb;                 // Tamaño en megabytes
  final DownloadResourceStatus status;  // upToDate | downloading | pending | error
  final double? progress;           // 0.0-1.0 durante descarga
  final DateTime? lastUpdatedAt;    // Última actualización
}
```

### SyncConfig
```dart
class SyncConfig {
  final bool wifiOnly;              // Sincronizar solo con WiFi
  final bool downloadPlanos;        // Descargar planos automáticamente
  final int usedSpaceMb;            // Espacio usado
  final int availableSpaceMb;       // Espacio disponible
}
```

## 🔄 Integración con Drift Database

### Tablas Utilizadas

#### SyncQueue
```dart
class SyncQueue extends Table {
  TextColumn get id => text()();              // UUID
  TextColumn get entity => text()();          // ACTIVITY | EVIDENCE | EVENT
  TextColumn get entityId => text()();        // ID de la entidad
  TextColumn get action => text()();          // UPSERT | DELETE
  TextColumn get payloadJson => text()();     // JSON del objeto
  IntColumn get priority => integer()();      // Prioridad (mayor = primero)
  IntColumn get attempts => integer()();      // Intentos realizados
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text()();          // PENDING | IN_PROGRESS | DONE | ERROR
}
```

#### SyncState
```dart
class SyncState extends Table {
  IntColumn get id => integer()();            // Siempre 1 (singleton)
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastServerCursor => text().nullable()();
  TextColumn get lastCatalogVersionByProjectJson => text()();
}
```

### Métodos del Repository

```dart
class SyncRepository {
  // Stream de estado global
  Stream<SyncHealth> watchSyncHealth();
  
  // Stream de cola de subida
  Stream<List<UploadQueueItem>> watchUploadQueue();
  
  // Reintentar ítem con error
  Future<void> retryItem(String itemId);
  
  // Forzar sincronización inmediata
  Future<void> forceSyncNow();
  
  // Obtener última sincronización
  Future<DateTime?> getLastSyncTime();
  
  // Actualizar timestamp de última sincronización
  Future<void> updateLastSyncTime(DateTime time);
  
  // Limpiar elementos completados antiguos
  Future<int> cleanCompletedOlderThan(Duration duration);
}
```

## 🎯 Navegación

### Acceso al Sync Center
1. **Desde Ajustes** → "Sincronización" o "Almacenamiento"
2. **URL Directa** → `/sync` (go_router)

### Configuración de Rutas
```dart
// lib/core/routing/app_router.dart
GoRoute(
  path: '/sync',
  name: 'sync',
 builder: (context, state) => const SyncCenterPage(),
),
```

## 🛠️ Estado Actual de Implementación

### ✅ Completado

- [x] **Modelos de datos** (`sync_models.dart`)
  - SyncHealth, UploadQueueItem, DownloadResource, SyncConfig
  - Enums: 5 tipos (SyncHealthStatus, UploadItemType, etc.)
  - Getters computados: icon, color, statusLabel

- [x] **UI Completa** (`sync_center_page.dart`)
  - Layout de 3 secciones con scroll
  - Health header animado con transiciones de color
  - Upload queue con progress bars y badges de estado
  - Download management con storage bar
  - Configuración con switches (WiFi-only, download planos)
  - Modal "Liberar espacio" con opciones
  - Info dialog explicativo

- [x] **Repository** (`sync_repository.dart`)
  - Streams de SyncHealth y Upload Queue
  - Métodos CRUD para SyncQueue
  - Helpers de formateo de tiempo
  - Mappers de Drift → Models

- [x] **Providers** (`sync_provider.dart`)
  - syncRepositoryProvider
  - syncHealthProvider (StreamProvider)
  - uploadQueueProvider (StreamProvider)
  - lastSyncTimeProvider (FutureProvider)
  - syncConfigProvider, downloadResourcesProvider

- [x] **Routing**
  - Ruta `/sync` integrada en app_router.dart
  - Navegación desde Settings habilitada
  - Import de SyncCenterPage

### 🚧 Pendiente de Integración

- [ ] **Conectar UI con Providers**
  - Reemplazar estado hardcoded en `_SyncCenterPageState`
  - Usar `ref.watch(syncHealthProvider)` en build
  - Usar `ref.watch(uploadQueueProvider)` para lista
  - Usar `ref.watch(syncConfigProvider)` para switches

- [ ] **Background Sync Service**
  - WorkManager para Android background tasks
  - Periodic sync cada 15 minutos
  - Exponential backoff en errores
  - Connectivity check antes de sync
  - Notificaciones de progreso

- [ ] **API Integration**
  - POST `/api/v1/sync/push` - Subir elementos de SyncQueue
  - GET `/api/v1/sync/pull` - Descargar cambios desde servidor
  - GET `/api/v1/resources/planos` - Descargar planos
  - Versionado con lastServerCursor (delta sync)

- [ ] **Conflict Resolution**
  - Detectar conflictos (last_modified_at)
  - UI de resolución: "Mi versión" vs "Versión del servidor"
  - Opción de merge manual
  - Log de resolución de conflictos

- [ ] **Storage Management**
  - Calcular tamaño real de DB + evidencias
  - Implementar "Liberar espacio" real:
    - Eliminar evidencias subidas
    - Limpiar caché de imágenes
    - Purgar SyncQueue con DONE > 7 días

- [ ] **Testing**
  - Unit tests para SyncRepository
  - Widget tests para SyncCenterPage
  - Integration tests para sync flow completo

## 📝 Próximos Pasos Recomendados

### Paso 1: Integrar Providers en UI (30 min)
```dart
// En _SyncCenterPageState, reemplazar:
final _syncHealth = ...  // ❌ Estado local

// Por:
final syncHealthAsync = ref.watch(syncHealthProvider);  // ✅ Provider

// En build():
syncHealthAsync.when(
  data: (syncHealth) => _buildHealthHeader(syncHealth),
  loading: () => CircularProgressIndicator(),
  error: (e, st) => Text('Error: $e'),
)
```

### Paso 2: Implementar Background Sync Service (2-3 horas)
```dart
// lib/features/sync/services/background_sync_service.dart
class BackgroundSyncService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await schedulePeriodicSync();
  }
  
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      // Lógica de sync
      return true;
    });
  }
}
```

### Paso 3: API Endpoints en Backend (2-3 horas)
```python
# backend_python/app/api/v1/sync.py
@router.post("/sync/push")
async def push_changes(items: List[SyncItem], db: Session = Depends(get_db)):
    # Procesar cola de subida
    for item in items:
        if item.entity == "ACTIVITY":
            # Upsert activity
        elif item.entity == "EVIDENCE":
            # Upload evidence
    return {"processed": len(items)}

@router.get("/sync/pull")
async def pull_changes(cursor: str, db: Session = Depends(get_db)):
    # Delta sync desde cursor
    changes = get_changes_since(cursor)
    return {"changes": changes, "cursor": new_cursor}
```

### Paso 4: Agregar Tests (1-2 horas)
```dart
// test/features/sync/sync_repository_test.dart
void main() {
  late AppDb db;
  late SyncRepository repo;

  setUp(() {
    db = AppDb.inMemory();
    repo = SyncRepository(db);
  });

  test('watchSyncHealth emits correct status', () async {
    // Insert test data into SyncQueue
    // Watch stream
    // Verify emitted SyncHealth
  });
}
```

## 🎨 Paleta de Colores

```dart
// Estados de salud
const healthGreen = Color(0xFF10B981);    // Todo sincronizado
const healthBlue = Color(0xFF3B82F6);     // Sincronizando
const healthRed = Color(0xFFEF4444);      // Error / Sin conexión
const healthAmber = Color(0xFFF59E0B);    // Advertencia / Pendiente

// Backgrounds
const bgGreen = Color(0xFFF0FDF4);        // Success light
const bgBlue = Color(0xFFDBEAFE);         // Info light
const bgRed = Color(0xFFFEE2E2);          // Error light
const bgAmber = Color(0xFFFEF3C7);        // Warning light

// Grays
const gray100 = Color(0xFFF8FAFC);        // Page background
const gray200 = Color(0xFFE5E7EB);        // Borders
const gray400 = Color(0xFF9CA3AF);        // Secondary text
const gray600 = Color(0xFF6B7280);        // Primary text
```

## 📚 Referencias

### Documentación Relacionada
- `IMPLEMENTATION_PLAN.md` → Fase 5: Sincronización Offline
- `ARCHITECTURE.md` → Sección "Data Sync Strategy"
- `lib/data/local/tables.dart` → Definición de SyncQueue y SyncState

### Patrones Implementados
- **Outbox Pattern**: Cola persistente antes de enviar al servidor
- **Optimistic UI**: Updates instantáneos, sync en background
- **Delta Sync**: Solo sincronizar cambios desde último cursor
- **Retry with Backoff**: Exponential backoff para errores transitorios

### UX Inspirations
- Google Keep (offline sync badge)
- Notion (sync status indicator)
- Todoist (offline mode banner)

## 🐛 Bugs Corregidos en Esta Sesión

### Bug Fix: hora_inicio preservation
**Problema**: Al hacer segundo swipe de "Termino" en home, se borraba `horaInicio` y `horaFin`.

**Causa**: Método `_reportIncident()` usaba objeto original `a` en lugar de estado actualizado.

**Solución**: ([home_page.dart](d:\\SAO\\frontend_flutter\\sao_windows\\lib\\features\\home\\home_page.dart#L320-L324))
```dart
// OLD (línea 320):
final updated = a.copyWith(executionState: ExecutionState.pendiente);

// NEW:
final currentActivity = _activityStates[a.id] ?? a;
final updated = currentActivity.copyWith(executionState: ExecutionState.pendiente);
```

**Impacto**: Ahora las horas registradas se preservan correctamente al reportar incidencias.

---

## 📞 Soporte

Para dudas sobre la implementación:
- Revisar comentarios TODO en código fuente
- Consultar `ARCHITECTURE.md` para decisiones de diseño
- Verificar providers en `sync_provider.dart`

**Última actualización**: 2025-01-XX por GitHub Copilot
