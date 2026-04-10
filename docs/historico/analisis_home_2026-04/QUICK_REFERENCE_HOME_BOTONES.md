# ⚡ TABLA DE REFERENCIA RÁPIDA - HOME SCREEN

## 📱 Todos los Botones Visibles - ¿Qué hace cada uno?

### Región: TOP (AppBar)

```
┌────────────────────────────────────────┐
│ 👤 │ Proyecto: TMQ ▼  │ ☁️ │ 🔔 (1)   │
└────────────────────────────────────────┘
```

| # | Icon | Nombre | Qué hace | Código |
|---|------|--------|----------|--------|
| A1 | 👤 | Avatar Usuario | Va a /profile | `context.push('/profile')` |
| A2 | ▼ | Selector Proyecto | Callback padre (no impl. local) | `widget.onTapProject()` |
| A3 | ☁️ | Cloud/Sync | Sincroniza todo | `_handleCloudAction()` → `syncAll()` |
| A4 | 🔔 | Notificaciones | Abre modal de alertas | `_openNotificationsCenter()` |

---

### Región: SEARCH & FILTERS (Bajo AppBar)

```
┌────────────────────────────────────────┐
│ 🔍 [Buscar PK... ]   ✕                 │
│ [5] Totales │ [1] Vencidas │ ...      │
│ [Hoy] [7 días] [1 mes]                │
└────────────────────────────────────────┘
```

| # | Elemento | Qué hace | Ruta/Función |
|---|----------|----------|---|
| S1 | 🔍 Search | Filtra por PK/Frente/Municipio en tiempo real | `setState(() => _query = v)` |
| S2 | ✕ Clear | Limpia búsqueda | `_clearSearch()` |
| S3 | Totales badge | Muestra todas (filter mode) | `_setFilterMode(FilterMode.totales)` |
| S4 | Vencidas badge | Filtra vencidas | `_setFilterMode(FilterMode.vencidas)` |
| S5 | Completadas badge | Filtra terminadas | `_setFilterMode(FilterMode.completadas)` |
| S6 | Pend. Sync badge | Filtra completadas sin sync | `_setFilterMode(FilterMode.pendienteSync)` |
| S7 | Hoy button | Fecha: hoy | `_setDateRangeFilter(DateRangeFilter.hoy)` |
| S8 | 7 días button | Fecha: últimos 7 d | `_setDateRangeFilter(DateRangeFilter.semana)` |
| S9 | 1 mes button | Fecha: últimos 30 d | `_setDateRangeFilter(DateRangeFilter.mes)` |

---

### Región: TASK SECTIONS (Centro)

```
┌────────────────────────────────────────┐
│ ▶ POR INICIAR (5)                      │ ← Expandible
│   Frente: Insurgentes (4)  ▼           │ ← Expandible
│   ├─ [ Tarjeta de Actividad ]          │
│   └─ [ Tarjeta de Actividad ]          │
│                                         │
│ ▼ EN CURSO (2)                         │ ← Expandido por defecto
│   Frente: Morelos (2)  ▲               │
│   ├─ [ Tarjeta de Actividad ]          │
│   └─ [ Tarjeta de Actividad ]          │
└────────────────────────────────────────┘
```

| # | Elemento | Qué hace | Función |
|---|----------|----------|---------|
| T1 | Section Header | Expande/contrae sección | Auto-expande si crítica |
| T2 | Frente Header [▼] | Expande/contrae por frente | `setState(() => _expandedByFrente[key] = !val)` |
| T3 | Contador Frente | Display solo | — |

---

### Región: ACTIVITY CARD (En cada tarjeta dentro sección)

```
┌─────────────────────────────────────┐
│ ┃ Título Actividad        ⚠️ [5+230] ↔️ │ ← Swipeable + Transferir
│ │ Frente: Insurgentes           │
│ │ Asignada a: Tú                │
│ │ Municipio: Valle de México    │
│ │ 🟢 En curso • Iniciada 09:30  │ ← Footer
│ │ [Sincronizar]                 │ ← Si completada + no synced
│ └─────────────────────────────────────┘
```

#### Tap/Click
| # | Acción | A qué abre | Función |
|---|--------|-----------|---------|
| C1 | Tap en card | Admin: `/activity/{id}`<br>Operativo: wizard captura | `context.push()` o `_openRegisterWizard()` |

#### Swipe Derecha →
| # | Estado | Acción | Función |
|---|--------|--------|---------|
| C2a | PENDIENTE | Iniciar | `_iniciarActividad()` → marca `startedAt` |
| C2b | EN_CURSO | Abrir captura | `_abrirWizardDesdeEnCurso()` → abre wizard |
| C2c | REVISION_PEND. | Reintentar | `_reintentarCaptura()` → reabre wizard |
| C2d | TERMINADA | — | (No se puede swipear) |

#### Swipe Izquierda ←
| # | Acción | Motivos | Función |
|---|--------|---------|---------|
| C3 | Reportar incidencia | • Clima<br>• Acceso denegado<br>• Riesgo<br>• Cancelada | `_reportIncident()` → Modal selector |

#### Botón Transferir (↔️)
| # | Condición Visible | Acción | Función |
|---|---|---|---|
| C4 | Operativo + asignada a él + no offline + no terminada | Abre modal transfer | `_openTransferResponsibilitySheet()` |
|    | Modal: Selecciona operativo + motivo opcional + "Transferir" | Transferencia | `_transferResponsibility()` |

#### Botón Sincronizar (🔄)
| # | Condición Visible | Acción |
|---|---|---|
| C5 | Solo si COMPLETADA + NO synced | Sincroniza | `_syncCompletedActivity()` |

#### Badges/Display (no clickeables)
| # | Badge | Visible si | Visual |
|---|-------|-----------|--------|
| C6 | ⚠️ No planeada | `a.isUnplanned` | Chip naranja |
| C7 | Rechazada | `isRejected` | Chip rojo |
| C8 | Pendiente | `executionState == revisionPendiente` | Chip rojo |
| C9 | [5+230] | `a.pk != null` | Chip monospace |
| C10 | 🟢 Sincronizada | Si completada | Badge verde |
| C11 | ⚠️ Pendiente | Si completada + syncState=pending | Badge naranja |
| C12 | 🔴 Error | Si completada + syncState=error | Badge rojo |

---

### Región: FLOATING ACTION BUTTON (esquina inferior derecha)

```
┌──────────────┐
│     ⚠️       │ ← Botón flota arriba del NavBar
│ Actividad    │
│ No Planeada  │
└──────────────┘
```

| # | Botón | Acción | Ruta |
|---|-------|--------|------|
| F1 | ⚠️ | Crear actividad fuera del plan | `/wizard/register?mode=unplanned` |

---

### Región: BOTTOM NAVIGATION BAR (pie de página)

```
[🏠 Inicio] [🔄 Sync] [📅 Agenda] [📋 Historial] [⚙️ Ajustes]
```

| # | Label | Icon (inactive/active) | Ruta | Implementado |
|---|-------|---|------|---|
| B1 | Inicio | 🏠 outlined / solid | `/` | ✅ |
| B2 | Sincronizar | 🔄 outlined / solid | `/sync` | ✅ |
| B3 | Agenda | 📅 outlined / solid | `/agenda` | ✅ |
| B4 | Historial | 📋 outlined / solid | `/history/completed` | ✅ |
| B5 | Ajustes | ⚙️ outlined / solid | `/settings` | ✅ |

---

## 📋 MODALS / BOTTOM SHEETS

### Modal: Centro de Notificaciones (onPress Alert Icon)

```
╔════════════════════════════════╗
║ 🔔 Notificaciones (2)          ║
╠════════════════════════════════╣
║ ❌ Actividad rechazada         ║ ← Tap abre activity
║    Título • Requiere corrección│
║                                ║
║ ⚠️ Actividad vencida           ║ ← Tap abre activity
║    Título • Frente             ║
╚════════════════════════════════╝
```

| # | Elemento | Acción |
|---|----------|--------|
| N1 | Notification item (tap) | Navega a `/activity/{id}` (admin) o abre wizard (operativo) |
| N2 | "Sin alertas" | Display si no hay |

---

### Modal: Reportar Incidencia (Swipe izquierda)

```
╔════════════════════════════════╗
║ 📋 Reportar incidencia         ║
╠════════════════════════════════╣
║ ☁️ Clima                       ║ ← Tap
║ 🔒 Acceso denegado            ║ ← Tap
║ ⚠️ Riesgo                      ║ ← Tap
║ ❌ Cancelada                   ║ ← Tap
╚════════════════════════════════╝
```

| # | Motivo | Acción |
|---|--------|--------|
| I1 | Clima | Reinicia a PENDIENTE, SnackBar "Clima" |
| I2 | Acceso denegado | Reinicia a PENDIENTE, SnackBar "Acceso denegado" |
| I3 | Riesgo | Reinicia a PENDIENTE, SnackBar "Riesgo" |
| I4 | Cancelada | Reinicia a PENDIENTE, SnackBar "Cancelada" |

---

### Modal: Transferir Responsabilidad (Botón ↔️)

```
╔════════════════════════════════╗
║ Transferir responsabilidad     ║
║ Título: Actividad XXX          ║
╠════════════════════════════════╣
║ ◉ Operativo 1 - Jefe de Equipo║ ← Tap para seleccionar
║ ○ Operativo 2 - Técnico        ║ ← Tap para seleccionar
║ ○ Operativo 3 - Apoyo          ║ ← Tap para seleccionar
╠════════════════════════════════╣
║ [Motivo (opcional)]            ║ ← TextField
║                                ║
║ [Cancelar] [Transferir]        ║ ← Botones
╚════════════════════════════════╝
```

| # | Elemento | Acción |
|---|----------|--------|
| T1 | Radio operativo | Selecciona `_selectedResourceId` |
| T2 | TextField motivo | Input opcional |
| T3 | Cancelar button | Cierra modal sin hacer nada |
| T4 | Transferir button | Ejecuta `_transferResponsibility()` → API |

---

## 🔍 BÚSQUEDA: CAMPOS BUSCABLES

El campo 🔍 busca en:
- `activity.title` (matching parcial, case-insensitive)
- `activity.frente` (matching parcial)
- `activity.municipio` (matching parcial)
- `activity.estado` (matching parcial)
- `activity.pk` formateado "km+m" (matching)
- `activity.pk` como números puros (matching)

**Ejemplo:** Buscar "5+2" encontrará PK 5+230, 5+250, etc.

---

## 🎨 COLORES Y ESTADOS VISUALES

### Barra Izquierda de Tarjeta

| ExecutionState | Color | Animación |
|---|---|---|
| PENDIENTE | Dinámico por status | Estática |
| EN_CURSO | Verde (success) | **Pulsante** |
| REVISION_PEND. | Naranja (warning) | **Pulsante** |
| TERMINADA | Verde (éxito) | Estática |

### Badges Métricos (Totales/Vencidas/etc)

| Estado | Color Border | Color Fondo | Sombra |
|---|---|---|---|
| No seleccionado | color.alpha(0.18) | color.alpha(0.10) | Ninguna |
| **Seleccionado** | **color.alpha(0.4)** | **color.alpha(0.18)** | **Sombra color.alpha(0.2)** |

---

## 🔐 CONDICIONES DE VISIBILIDAD

### Botón Transferir (↔️) - Desaparece si:
- ❌ Usuario es ADMIN (solo para operativos)
- ❌ App está OFFLINE
- ❌ Actividad está TERMINADA
- ❌ Actividad NO está asignada al usuario actual

### Botón Sincronizar (🔄) - Desaparece si:
- ❌ Actividad NO está COMPLETADA
- ❌ Ya está SINCRONIZADA

### Sección "Por Corregir" - AUTO-EXPAND si:
- ✅ Hay items en esta sección (es crítica)

### Swipe Izquierda - DESHABILITADO si:
- ❌ Actividad está RECHAZADA

---

## 📊 TABLA RÁPIDA: QUICK REFERENCE

```
┌─ ELEMENTO ─────────────┬─ ESTADO ─┬─ FUNCIÓN ────────────────┐
│ Avatar Usuario          │ ✅      │ → /profile               │
│ Proyecto Selector       │ ⚠️      │ → callback padre         │
│ Cloud Sync              │ ✅      │ → syncAll()              │
│ Notificaciones          │ ✅      │ → modal alerts           │
│ 🔍 Search              │ ✅      │ → filter realtime        │
│ ✕ Clear Search         │ ✅      │ → clear query            │
│ Badges Métricos (4x)    │ ✅      │ → _setFilterMode()       │
│ Date Range (3x)         │ ✅      │ → _setDateRangeFilter()  │
│ Frente Expandible       │ ✅      │ → toggle expand          │
│ Tap Card                │ ✅      │ → wizard / detail        │
│ Swipe →                 │ ✅      │ → start/finish/capture   │
│ Swipe ←                 │ ✅      │ → report incident        │
│ Transferir ↔️           │ ✅      │ → transfer modal         │
│ Sincronizar 🔄          │ ✅      │ → sync completed         │
│ FAB ⚠️                  │ ✅      │ → unplanned activity     │
│ BottomNav (5x)          │ ✅      │ → navega secciones       │
└─────────────────────────┴─────────┴──────────────────────────┘

TOTAL: 40/41 = 97.56% ✅
```

---

## 🚀 CÓMO USAN CADA BOTÓN LOS USUARIOS

### Flujo Típico (Operativo)

1. **Inicia app** → Abre HOME
2. **Ve tarjetas**en "POR INICIAR"
3. **Swipe derecha** en tarjeta → Marca iniciada (verde/EN_CURSO)
4. **Swipe derecha again** → Abre WIZARD para capturar datos
5. **Guarda captura** → Marca completada (TERMINADA)
6. **Ve botón 🔄 Sincronizar** → Tap para sincronizar
7. **Navega a otra sección** con BottomNav o cambia filtro

### Flujo Incidencia (Obstáculo)

1. **En tarjeta PENDIENTE**
2. **Swipe izquierda** → Modal selector incidencia
3. **Tap "Clima"** (por ejemplo)
4. **Tarjeta reinicia** a PENDIENTE con motivo registrado

### Flujo Transferencia (Cambio de responsable)

1. **Tarjeta PENDIENTE asignada a mi**
2. **Botón ↔️ Transferir** visible
3. **Tap botón** → Modal con operativos
4. **Selecciona operativo** + optional motivo
5. **Tap "Transferir"** → API actualiza

---

**Versión:** 1.0 | **Fecha:** 30-Mar-2026

