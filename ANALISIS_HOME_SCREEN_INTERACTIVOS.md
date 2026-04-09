# ANÁLISIS COMPLETO: Pantalla HOME/INICIO - Elementos Interactivos

## 📋 INFORMACIÓN GENERAL

**Archivo Principal:** [frontend_flutter/sao_windows/lib/features/home/home_page.dart](frontend_flutter/sao_windows/lib/features/home/home_page.dart)

**Clase:** `HomePage` (extends `ConsumerStatefulWidget`) → `_HomePageState`

**Widgets Relacionados:**
- [home_task_sections.dart](frontend_flutter/sao_windows/lib/features/home/home_task_sections.dart) - Secciones de tareas
- [widgets/home_task_inbox.dart](frontend_flutter/sao_windows/lib/features/home/widgets/home_task_inbox.dart) - Contenedor principal
- [core/navigation/shell.dart](frontend_flutter/sao_windows/lib/core/navigation/shell.dart) - Navegación inferior
- [core/routing/app_router.dart](frontend_flutter/sao_windows/lib/core/routing/app_router.dart) - Rutas

---

## 🎯 ESTRUCTURA DE UI PRINCIPAL

### 1. BARRA SUPERIOR (AppBar) - SLIVER APP BAR

#### Elementos:
- **Avatar de usuario** (CircleAvatar)
  - `onTap:` `context.push('/profile')`
  - **Estado:** ✅ IMPLEMENTADO
  - Abre la página de perfil del usuario

- **Selector de Proyecto** (InkWell → Row)
  - `onTap:` `widget.onTapProject`
  - **Estado:** ⚠️ PARCIALMENTE IMPLEMENTADO
  - El callback viene del padre pero sin funcionalidad real (solo navega)

- **Botón Cloud/Sincronización** (IconButton)
  - `onPressed:` `_handleCloudAction(isOffline: isOffline, isSyncing: isSyncing)`
  - **Estado:** ✅ IMPLEMENTADO
  - Iconografía dinámica: `Icons.cloud_upload_rounded | cloud_done_rounded | cloud_off_rounded`
  - Tooltip dinámico según estado (Sincronizando/Error/Offline/Online)
  - Ejecuta sincronización completa

- **Botón Notificaciones** (Stack + IconButton)
  - `onPressed:` `_openNotificationsCenter()`
  - **Estado:** ✅ IMPLEMENTADO
  - Badge dinámico mostrando `_notificationCount`
  - Abre Modal Bottom Sheet con lista de notificaciones
  - Acciones: Can tap items para abrir actividades

---

### 2. ÁREA DE BÚSQUEDA Y FILTROS

#### Buscador
- **Campo de búsqueda** (TextField en Container con BorderRadius circular)
  - `onChanged:` `setState(() => _query = v)`
  - **Estado:** ✅ IMPLEMENTADO
  - Búsqueda por: PK, Frente, Municipio, Estado, Título
  - Hint: "Buscar PK, Frente, Municipio…"

- **Botón Limpiar búsqueda** (IconButton)
  - `onPressed:` `_clearSearch()`
  - **Estado:** ✅ IMPLEMENTADO
  - Visible solo cuando hay texto en búsqueda
  - Icon: `Icons.close_rounded`

#### Métricas/Contadores (4 badges)
Implementados como `_MetricBadge` widgets interactivos:

| Badge | Count | Color | onTap Implementado | Acción |
|-------|-------|-------|-------------------|--------|
| **Totales** | Todas las actividades filtradas | Gray500 | ✅ YES | `_setFilterMode(FilterMode.totales)` |
| **Vencidas** | Actividades con status=vencida | Error | ✅ YES | `_setFilterMode(FilterMode.vencidas)` |
| **Completadas** | executionState=terminada | Success | ✅ YES | `_setFilterMode(FilterMode.completadas)` |
| **Pend. Sync** | terminada + syncState=pending | Warning | ✅ YES | `_setFilterMode(FilterMode.pendienteSync)` |

- **Estado:** ✅ TOTALMENTE IMPLEMENTADO
- Cada badge es un `InkWell` con `onTap`
- Select visual state (border + color dinámica)

#### Filtro de Rango de Fechas
- **SegmentedButton<DateRangeFilter>** con 3 opciones:
  - "Hoy" → `DateRangeFilter.hoy`
  - "7 días" → `DateRangeFilter.semana`
  - "1 mes" → `DateRangeFilter.mes`
  
- `onSelectionChanged:` Actualiza `_setDateRangeFilter(selection.first)`
- **Estado:** ✅ IMPLEMENTADO
- Filtra actividades por rango de createdAt

---

### 3. SECCIONES DE ACTIVIDADES

#### Task Sections (7 secciones por next_action)
| ID | Nombre Mostrado | Icon | Color | Implementado |
|----|----|----|----|------|
| `por_iniciar` | "Por iniciar" | play_circle_fill | primary | ✅ |
| `en_curso` | "En curso" | timelapse | success | ✅ |
| `por_completar` | "Por completar" | edit_note | warning | ✅ |
| `por_corregir` | "Por corregir" | assignment_late | riskHigh | ✅ |
| `error_sync` | "Error de sincronización" | cloud_off | error | ✅ |
| `pendiente_sync` | "Pendiente de sincronizar" | cloud_upload | info | ✅ | 
| `en_revision` | "En revisión" | fact_check | actionPrimary | ✅ |

#### Expansion de Secciones por Frente
- **_FrenteSection** (InkWell col expandible)
  - `onTap:` `setState(() => _expandedByFrente[expansionKey] = !expanded)`
  - **Estado:** ✅ IMPLEMENTADO
  - Muestra: Nombre frente + contador + icono expand/collapse
  - Almacena estado globalmente en `_expandedByFrente` (Map<String, bool>)

---

### 4. TARJETA DE ACTIVIDAD (_SwipeActivityTile → _ActivityTile)

**Elemento más importante con múltiples interacciones:**

#### A. Estructura Base
- **Dismissible Widget** (permite swipe gestures)
  - Dirección: Horizontal (izquierda/derecha)
  - `confirmDismiss:` Maneja swipes SIN eliminar (returnfalse)

#### B. Swipe Derecha
- **Background Visual:**
  - Color dinámico según ExecutionState + icono + label
  - Muestra: "Iniciar" / "Terminar" / "Capturar" / "Completada"

- **Función:** `onSwipeRight()` → `_onSwipeRight(TodayActivity)`
  - **Estado:** ✅ IMPLEMENTADO
  - Ejecuta: 
    - Si PENDIENTE: `_iniciarActividad()` (marca startedAt)
    - Si EN_CURSO: `_abrirWizardDesdeEnCurso()` (abre formulario)
    - Si REVISION_PENDIENTE: `_reintentarCaptura()` (reintenta wizard)
  - Haptic feedback: `HapticFeedback.mediumImpact()`

#### C. Swipe Izquierda
- **Secondary Background Visual:**
  - Color: riskHigh.withAlpha(0.18)
  - Muestra: "Incidencia" + icon report_problem

- **Función:** `onSwipeLeftIncident()` → `_reportIncident(TodayActivity)`
  - **Estado:** ✅ IMPLEMENTADO
  - Abre Modal Bottom Sheet con 4 motivos predefinidos:
    - "Clima" (Icon: cloud)
    - "Acceso denegado" (Icon: lock)
    - "Riesgo" (Icon: warning)
    - "Cancelada" (Icon: cancel)
  - Reinicia actividad a PENDIENTE con motivo registrado

#### D. Tap en Card (InkWell)
- **onTap:** `onTapOpenWizard()`
  - Si es Admin: `context.push('/activity/{id}?project=...')`
  - Si es Operativo: `_openRegisterWizard(activity)`
  - **Estado:** ✅ IMPLEMENTADO

#### E. Botón Transferir Responsabilidad
- **Ubicación:** Arriba-derecha de tarjeta (solo si es operativo y asignado a él)
- **IconButton** (swap_horiz_rounded)
  - `onPressed:` `_openTransferResponsibilitySheet(currentActivity)`
  - **Estado:** ✅ IMPLEMENTADO
  - Abre Modal Bottom Sheet con:
    - Lista de operativos disponibles (radio selection)
    - Campo de texto para motivo opcional
    - Botones: "Cancelar" / "Transferir"
  - Condición: `_canTransferResponsibility(activity)` verifica:
    - Solo operativos (no admin)
    - No offline
    - No terminada
    - Asignada al usuario actual

#### F. Botón Sincronizar (solo si completada)
- **TextButton.icon**
  - Label: "Sincronizar"
  - Icon: sync_rounded
  - `onPressed:` `onSyncCompleted()` → `_syncCompletedActivity()`
  - **Estado:** ✅ IMPLEMENTADO
  - Visible solo si: `executionState == terminada && syncState != synced`

#### G. Badge "No planeada"
- **Mostrado si:** `a.isUnplanned == true`
- **Visual:** Chip con warning color + icon warning
- **Sem acción (solo display)

#### H. Badge "Rechazada" / "Pendiente"
- **Rechazada si:** `isRejected == true`
- **Pendiente si:** `executionState == revisionPendiente && !isRejected`
- **Visual:** Chip con riskHigh color
- **Sin acción (solo display)

#### I. PK Display
- **Mostrado si:** `a.pk != null`
- **Formato:** "km+m" (ej: "5+230")
- **Visual:** Chip monospace en gray
- **Sin acción (solo display)**

#### J. Barra Izquierda Pulsante (_PulsingBar)
- **Color dinámico** según estado de ejecución
- **Anima (pulse)** si: `isActive || needsAttention`
- **Función:** Indicador visual, sin acción

#### K. Información Mostrada
- Título (max 2 lineas)
- Frente (si búsqueda activa)
- Asignado a: (con icono person_pin_circle)
- Municipio, Estado
- Footer: Icono + estado + chevron_right (navegación visual)
- Badge de sync state (si completada): Sincronizada/Pendiente/Error

---

### 5. FLOTANTE (FloatingActionButton)

#### Botón "Actividad No Planeada"
- **FloatingActionButton.small** (Column de botones)
- Icon: `Icons.warning_rounded`
- backgroundColor: riskHigh
- `onPressed:` 
  ```dart
  context.push('/wizard/register?project={projectId}&mode=unplanned')
  ```
- **Estado:** ✅ IMPLEMENTADO
- Abre wizard en modo "unplanned" para crear actividades fuera del plan

---

### 6. NAVEGACIÓN INFERIOR (BottomNavigationBar)

**Ubicación:** Definida en [core/routing/app_router.dart](frontend_flutter/sao_windows/lib/core/routing/app_router.dart#L433)

| Posición | Label | Icon | onTap Destino | Implementado |
|----------|-------|------|---|---|
| 0 | **Inicio** | home_outlined / home | `context.go('/')` | ✅ |
| 1 | **Sincronizar** | sync_outlined / sync | `context.go('/sync')` | ✅ |
| 2 | **Agenda** | calendar_today_outlined / calendar_today | `context.go('/agenda')` | ✅ |
| 3 | **Historial** | history_outlined / history | `context.go('/history/completed')` | ✅ |
| 4 | **Ajustes** | settings_outlined / settings | `context.go('/settings')` | ✅ |

- **Estado:** ✅ TOTALMENTE IMPLEMENTADO
- Implementado en `_NavigationScaffold` StateFullWidget
- `onTap:` Llama `_onItemTapped(index, context)` para navegar

---

## 📱 ESTADOS ESPECIALES

### Tutorial Mode
- **Mostrado si:** URL contiene `?tutorial=1`
- **Elemento:** Info banner con instrucciones
- **Sin acciones interactivas**

### Admin Viewer Mode
- **Botón "Historial"** + **Botón "Estadísticas"**
  - `onTap:` `context.push('/admin/history')` / `context.push('/admin/stats')`
  - **Estado:** ✅ IMPLEMENTADO
  - Solo visible para admin viewers

### Loading State
- **CircularProgressIndicator** fullscreen mientras `_loadingActivities == true`
- **Estado:** ✅ IMPLEMENTADO

### Empty State
- **_EmptyState Widget** (título + subtítulo + botón limpiar)
- Mostrado cuando sin no hay actividades o sin resultados en búsqueda
- **Estado:** ✅ IMPLEMENTADO

---

## 🔗 FLUJOS DE DATOS Y ESTADO

### State Management
- **Riverpod** para providers:
  - `offlineModeProvider` - Estado offline
  - `syncOrchestratorProvider` - Estado de sync
  - `currentUserProvider` - Usuario actual
  - `kvStoreProvider` - Almacenamiento persistente
  - `catalogSyncServiceProvider` - Sincronización de catálogo
  
- **Local State (_HomePageState)**:
  - `_items: List<TodayActivity>` - Actividades en memoria
  - `_filterMode: FilterMode` - Modo filtro activo
  - `_dateRangeFilter: DateRangeFilter` - Rango de fechas
  - `_query: String` - Texto de búsqueda
  - `_expandedByFrente: Map<String, bool>` - Expansión por frente
  - `_transferringActivityIds: Set<String>` - IDs transferencias en progreso

### Cargas de Datos
- **`_loadHomeActivities()`** - Carga lista de actividades desde DB local
- **`_syncAssignmentsForHome()`** - Sincroniza asignaciones desde backend
- **`_loadOperativeVisibleActivityIds()`** - Resuelve visibilidad para operativos
- **`_resolveViewerRole()`** - Determina admin vs operativo

### Persistencia
- **Shared Preferences** (via `kvStoreProvider`):
  - `home_filter_mode`
  - `home_date_range_filter`
  - `selected_project`

---

## ✅/❌ RESUMEN DE IMPLEMENTACIÓN

### COMPLETAMENTE IMPLEMENTADOS (✅)

| Elemento | Función | Línea |
|----------|---------|-------|
| Buscador | Filter por PK/Frente/Municipio | ~1950 |
| Botón Limpiar Búsqueda | Clear query | ~1970 |
| 4 Badges Métricos | Filter por: Totales/Vencidas/Completadas/PendSync | ~1997-2035 |
| SegmentedButton Fechas | Filtrar por: Hoy/7 días/1 mes | ~2043 |
| Avatar Usuario | Navega a /profile | ~1865 |
| Botón Cloud Sync | Sincroniza todas actividades | ~1902 |
| Botón Notificaciones | Abre centro de notificaciones | ~1917 |
| Swipe Derecha | Iniciar/Terminar/Capturar actividades | ~1318, 2647 |
| Swipe Izquierda | Reportar incidencia | ~1499, 2668 |
| Tap Card | Abrir wizard o detalle | ~2714 |
| Botón Transferir | Transferir responsabilidad a operativo | ~2919 |
| Botón Sincronizar (card) | Sincronizar actividad completada | ~2948 |
| FAB Actividad No Planeada | Crear unplanned activity | ~1849 |
| BottomNavigationBar | Navegar entre Inicio/Sync/Agenda/Historial/Ajustes | 433 (app_router) |
| Frente Section Toggle | Expandir/contraer secciones | ~2380 |
| Push Notifications | Auto-sincroniza catálogo | ~220 |
| Catalog Auto-Check | Verifica catálogo cada 5 min | ~169 |

### PARCIALMENTE IMPLEMENTADOS (⚠️)

| Elemento | Estado | Notas |
|----------|--------|-------|
| Selector de Proyecto | Callback existe pero sin funcionalidad real | Widget.onTapProject vacío |
| Admin Panel (Historial/Stats) | Navega pero rutas pueden no existir | Depende de /admin/* |

### NO IMPLEMENTADOS (❌)

---

## 🎨 PATRONES VISUALES DINÁMICOS

### Colores por Estado de Ejecución
```
ExecutionState.pendiente → Color según status (vencida/hoy/programada)
ExecutionState.enCurso → Verde (SaoColors.success)
ExecutionState.revisionPendiente → Ámbar (SaoColors.warning) o Rojo si rechazada
ExecutionState.terminada → Verde (éxito)
```

### Iconos Dinámicos
```
pendiente → status icon (warning/schedule/event)
enCurso → play_circle_fill o timelapse
revisionPendiente → edit_note o cancel (si rechazada)
terminada → verified
```

### Estados de Sync Badge
```
synced → Verde "Sincronizada" (cloud_done)
pending → Ámbar "Pendiente" (cloud_upload)
error → Rojo "Error" (cloud_off)
unknown → Gris "Sin estado" (cloud_queue)
```

---

## 📊 DISTRIBUCIÓN DE CÓDIGO

| Archivo | Líneas | Propósito |
|---------|--------|----------|
| home_page.dart | ~3100 | Lógica completa + UI |
| home_task_sections.dart | ~200 | Definición de secciones |
| home_task_inbox.dart | ~100 | Contenedor de secciones |
| shell.dart | ~100 | Navegación (obsoleto - ver app_router.dart) |
| app_router.dart | ~500+ | Rutas y navegación final |

---

## 🔍 BÚSQUEDAS Y FILTROS - CAMPOS

La búsqueda coincide contra:
- `activity.title` (búsqueda completa)
- `activity.frente` (búsqueda frente)
- `activity.municipio` (búsqueda municipio)
- `activity.estado` (búsqueda estado)
- `activity.pk` formateado como "km+m" (búsqueda PK)
- `activity.pk` como dígitos (búsqueda PK sin formato)

Filtros activos:
1. **By FilterMode:** Totales/Vencidas/Completadas/PendSync
2. **By DateRange:** Hoy (today) / Semana (last 7 days) / Mes (last 30 days)
3. **By Query:** Full-text search campos arriba
4. **By OperativeRules:** Solo next_actions permitidos para operativos
5. **By Assignment:** Solo actividades asignadas al usuario (operativos)

---

## 🎯 PUNTOS CRÍTICOS

1. **Sincronización automática de catálogo** cada 5 minutos si online
2. **Push notifications** para actualizaciones de catálogo
3. **Transfer responsability** solo si operativo, no offline, no terminada
4. **Animaciones pulsantes** en barras izquierda cuando activa o pendiente
5. **Estado persistente** de filtros en SharedPreferences
6. **Haptic feedback** en swipe derecho
7. **Modo tutorial** desactiva funcionalidad real de wizard
8. **Admin vs Operativo** lógica diferencia visibilidad y funciones

---

## 📝 CONCLUSIÓN

La pantalla HOME está **~95% implementada**. Todos los elementos principales tienen funciones `onPressed`/`onTap` definidas y operativas. Solo detalles como la selección de proyecto parecen estar parcialmente incompletos, pero la navegación y filtros funcionan completamente.

