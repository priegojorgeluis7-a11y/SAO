# 📱 MAPA DE INTERACTIVIDAD - HOME SCREEN (RESUMEN RÁPIDO)

## 🎯 VISTA DE PÁGINA COMPLETA

```
┌─────────────────────────────────────────────┐
│ 👤 Avatar  │ Proyecto: TMQ ▼  ☁️  🔔 (1)   │ ← AppBar con avatarProfile, cloudSync, notificationCenter
├─────────────────────────────────────────────┤
│ 🔍 [Buscar PK, Frente... ] ✕               │ ← Search bar con clearButton
├─────────────────────────────────────────────┤
│ 5 | Vencidas │ 3 | Completadas │ 0 | Pend.  │ ← Metric badges (4 botones)
├─────────────────────────────────────────────┤
│ [Hoy] [7 días] [1 mes]                      │ ← Date range filter (3 botones)
├─────────────────────────────────────────────┤
│                                              │
│ ▶ POR INICIAR (5)                            │ ← Section header
│   Frente: Insurgentes (4)  ▼                 │ ← Expandable section
│   ├─ ┃ Actividad 1                           │
│   │  ├─ Municipio: Valle…    [5+230]         │
│   │  ├─ Asignada a: Tú                       │
│   │  └─ Pendiente • Vence hoy  →             │ ← Swipeable card
│   │  [Play icon for swipe right]             │
│   │  
│   └─ ┃ Actividad 2  ⚠️ Rechazada  ↔️        │
│      (Similar structure)                     │
│                                              │
│ ▶ EN CURSO (2)                               │
│   Frente: Morelos (2)  ▼                     │
│   └─ (2 actividades)                         │
│                                              │
│ ▶ POR COMPLETAR (1)  ← Critical section      │
│ ▶ POR CORREGIR (0)                           │
│ ▶ ERROR SYNC (0)                             │
│ ▶ PENDIENTE SYNC (0)                         │
│                                              │
├─────────────────────────────────────────────┤
│ ⚠️ [Actividad No Planeada]    ← FAB button   │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  🏠 Inicio  │ 🔄 Sync │ 📅 Agenda │ 📋 Hist │ ⚙️ │ ← BottomNavBar
└─────────────────────────────────────────────┘
```

---

## 🔘 TODOS LOS BOTONES E ICONOS INTERACTIVOS

### ZONA SUPERIOR (AppBar)

| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| 1 | 👤 Avatar Usuario | Abre /profile | `context.push('/profile')` | ✅ |
| 2 | Proyecto: TMQ ▼ | Widget.onTapProject callback | `widget.onTapProject()` | ⚠️ |
| 3 | ☁️ Cloud Icon | Sincronizar todo | `_handleCloudAction()` | ✅ |
| 4 | 🔔 Notificaciones | Abre centro notificaciones | `_openNotificationsCenter()` | ✅ |

### ZONA BÚSQUEDA Y FILTROS

| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| 5 | 🔍 Búsqueda | Filter actividades | `setState(() => _query = v)` | ✅ |
| 6 | ✕ Limpiar | Clear search | `_clearSearch()` | ✅ |
| 7 | Badge: Totales | Filter modo | `_setFilterMode(FilterMode.totales)` | ✅ |
| 8 | Badge: Vencidas | Filter modo | `_setFilterMode(FilterMode.vencidas)` | ✅ |
| 9 | Badge: Completadas | Filter modo | `_setFilterMode(FilterMode.completadas)` | ✅ |
| 10 | Badge: Pend. Sync | Filter modo | `_setFilterMode(FilterMode.pendienteSync)` | ✅ |
| 11 | SegmentedButton: Hoy | Set date range | `_setDateRangeFilter(DateRangeFilter.hoy)` | ✅ |
| 12 | SegmentedButton: 7 días | Set date range | `_setDateRangeFilter(DateRangeFilter.semana)` | ✅ |
| 13 | SegmentedButton: 1 mes | Set date range | `_setDateRangeFilter(DateRangeFilter.mes)` | ✅ |

### ZONA TAREAS (Secciones)

| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| 14 | Frente: XXX ▼ | Expandir/contraer | `setState(() => _expandedByFrente[key] = !expanded)` | ✅ |
| 15 | Contador Frente | (Display only) | — | — |

### ZONA TARJETAS DE ACTIVIDAD

| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| 16 | 📱 Card (Tap) | Abrir wizard/detalle | `_openRegisterWizard()` o `/activity/{id}` | ✅ |
| 17 | ➡️ Swipe Derecha | Iniciar/Terminar/Capturar | `_onSwipeRight()` | ✅ |
|    | — Play icon | (Swipe indicator) | — | — |
| 18 | ⬅️ Swipe Izquierda | Reportar incidencia | `_reportIncident()` | ✅ |
|    | — Exclamation | (Swipe indicator) | — | — |
| 19 | ↔️ Botón Transferir | Transferir a operativo | `_openTransferResponsibilitySheet()` | ✅ |
| 20 | 🔄 Botón Sincronizar | Syncear actividad | `_syncCompletedActivity()` | ✅ |

### FLOATING ACTION BUTTON (FAB)

| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| 21 | ⚠️ Actividad No Planeada | Crear unplanned | `/wizard/register?mode=unplanned` | ✅ |

### NAVEGACIÓN INFERIOR (BottomNavigationBar)

| # | Posición | Label | Icono | Acción | Estado |
|---|----------|-------|-------|--------|--------|
| 22 | 0 | Inicio | 🏠 | `context.go('/')` | ✅ |
| 23 | 1 | Sincronizar | 🔄 | `context.go('/sync')` | ✅ |
| 24 | 2 | Agenda | 📅 | `context.go('/agenda')` | ✅ |
| 25 | 3 | Historial | 📋 | `context.go('/history/completed')` | ✅ |
| 26 | 4 | Ajustes | ⚙️ | `context.go('/settings')` | ✅ |

### MODAL SHEETS (Abiertos por acciones)

#### Centro de Notificaciones
| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| N1 | Notificación (Tap) | Abrir actividad | `/activity/{id}` or `_openRegisterWizard()` | ✅ |

#### Reporte de Incidencia
| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| I1 | "Clima" (Tap) | Report + close | `Navigator.pop(ctx, 'Clima')` | ✅ |
| I2 | "Acceso denegado" (Tap) | Report + close | `Navigator.pop(ctx, 'Acceso denegado')` | ✅ |
| I3 | "Riesgo" (Tap) | Report + close | `Navigator.pop(ctx, 'Riesgo')` | ✅ |
| I4 | "Cancelada" (Tap) | Report + close | `Navigator.pop(ctx, 'Cancelada')` | ✅ |

#### Transferir Responsabilidad
| # | Elemento | Acción | Código | Estado |
|---|----------|--------|--------|--------|
| T1 | Radio Operativo | Select recipient | `_selectedResourceId = candidate.id` | ✅ |
| T2 | Botón Cancelar | Close dialog | `Navigator.pop(ctx)` | ✅ |
| T3 | Botón Transferir | Execute transfer | `_transferResponsibility()` | ✅ |

---

## 📊 RESUMEN ESTADÍSTICAS

| Categoría | Cantidad | ✅ | ⚠️ | ❌ |
|-----------|----------|----|----|-----|
| AppBar Elements | 4 | 3 | 1 | 0 |
| Search & Filters | 9 | 9 | 0 | 0 |
| Task Sections | 7 | 7 | 0 | 0 |
| Activity Card | 6 | 6 | 0 | 0 |
| FAB Actions | 1 | 1 | 0 | 0 |
| BottomNav Items | 5 | 5 | 0 | 0 |
| Modal Actions | 9 | 9 | 0 | 0 |
| **TOTAL** | **41** | **40** | **1** | **0** |

**Implementación Global: 97.56% ✅**

---

## 🔄 FLUJOS PRINCIPALES

### Flujo 1: Iniciar Actividad
```
Tarjeta PENDIENTE + Swipe Derecha
  ↓
_onSwipeRight() → _iniciarActividad()
  ↓
Marca startedAt = now
  ↓
UI: ExecutionState → EnCurso (color verde)
```

### Flujo 2: Terminar Actividad  
```
Tarjeta EN_CURSO + Swipe Derecha
  ↓
_abrirWizardDesdeEnCurso()
  ↓
context.push('/activity/{id}/wizard')
  ↓
Abre formulario de captura
```

### Flujo 3: Incidencia  
```
Tarjeta (cualquier estado) + Swipe Izquierda
  ↓
_reportIncident() → Modal Bottom Sheet
  ↓
Usuario selecciona motivo: Clima/Acceso/Riesgo/Cancelada
  ↓
Reinicia a PENDIENTE + registra motivo en incidencias
```

### Flujo 4: Transferir Responsabilidad
```
Tarjeta PENDIENTE/EN_CURSO + Botón ↔️ (si asignada a usuario)
  ↓
_openTransferResponsibilitySheet()
  ↓
Modal: Seleccionar operativo + motivo opcional
  ↓
_transferResponsibility() → API PATCH /assignments/{id}
  ↓
Actualiza DB local + recarga Home
```

### Flujo 5: Sincronizar
```
Tarjeta COMPLETADA + syncState != synced + Botón 🔄
  ↓
_syncCompletedActivity()
  ↓
ref.read(syncOrchestratorProvider).syncAll()
  ↓
Carga actividades nuevamente
```

### Flujo 6: Navegar Secciones
```
Búsqueda/Filtro activo
  ↓
filtered list actualizado
  ↓
buildHomeTaskSections() agrupa por next_action
  ↓
Cada sección agrupada por Frente
  ↓
Usuario expande/contrae Frente con botón ▼
```

---

## 🎭 ESTADOS VISUALES DINÁMICOS

### Colores de Barra Izquierda por ExecutionState
```
🔴 PENDIENTE        → Color según status (Vencida=Rojo, Hoy=Naranja, Prog=Gris)
🟢 EN_CURSO         → Verde (success)
⚠️ REVISION_PEND.   → Naranja (warning) / Rojo si rechazada
✅ TERMINADA        → Verde (completada)
```

### Estados de Animación
```
EN_CURSO           → Barra izquierda pulse (parpádeo)
REVISION_PEND.     → Barra izquierda pulse
OTROS              → Barra estática
```

### Badge Sincronización (si completada)
```
🟢 Sincronizada    → cloud_done + texto verde
⚠️ Pendiente       → cloud_upload + texto naranja  
🔴 Error           → cloud_off + texto rojo
⚪ Sin estado       → cloud_queue + texto gris

+ Botón "sincronizar" si pendiente o error
```

---

## 🔐 CONDICIONES DE VISIBILIDAD

### Botón Transferir ↔️
```
Visible si:
  - Usuario es OPERATIVO (no admin)
  - Actividad asignada al usuario actual
  - No está OFFLINE
  - Actividad NO está TERMINADA
  
Desaparecido durante transferencia (spinner animado)
```

### Botón Sincronizar 🔄
```
Visible si:
  - Actividad.executionState == TERMINADA
  - actividad.syncState != SYNCED
```

### Badge Sincronización
```
Visible si:
  - Actividad.executionState == TERMINADA
```

### Incidencia (Swipe izquierda)
```
Deshabilitado si:
  - isRejected == true
```

### Section Headers Expandibles
```
POR_CORREGIR, ERROR_SYNC → Auto-expand (critical priority)
Otros → Collapse by default
```

---

## 📦 ARCHIVOS CLAVE

### Lógica Principal
[home_page.dart](d:\SAO\frontend_flutter\sao_windows\lib\features\home\home_page.dart)
- Línea 1700: `build()` method
- Línea 1318: `_onSwipeRight()`
- Línea 1499: `_reportIncident()`
- Línea 750: `_transferResponsibility()`

### Navegación
[app_router.dart](d:\SAO\frontend_flutter\sao_windows\lib\core\routing\app_router.dart)
- Línea 433: BottomNavigationBar definición

### Componentes
[home_task_inbox.dart](d:\SAO\frontend_flutter\sao_windows\lib\features\home\widgets\home_task_inbox.dart)
- HomeTaskSectionCard
- HomeTaskInboxList

---

## ⚡ ANOTACIONES IMPORTANTES

1. **Haptic Feedback**: Solo en swipe derecha (`HapticFeedback.mediumImpact()`)
2. **Push Notifications**: Auto-sincroniza catálogo cuando llega actualización
3. **Catálogo Auto-Check**: Cada 5 minutos si online
4. **Modo Tutorial**: Desactiva funcionalidad real de wizard (`?tutorial=1`)
5. **Estado Persistente**: FilterMode y DateRange guardados en SharedPreferences
6. **Seguridad Operativo**: Filtrado automático por usuario asignado
7. **Snapshots**: Dismissible NO elimina card (confirmDismiss devuelve false)

