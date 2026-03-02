# 🎨 Sistema de Diseño SAO
## Guía Completa de Diseño Global para Mobile y Desktop

---

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Paleta de Colores](#paleta-de-colores)
4. [Tipografía](#tipografía)
5. [Espaciado y Layout](#espaciado-y-layout)
6. [Motion System (Animaciones)](#motion-system-animaciones)
7. [Componentes Compartidos](#componentes-compartidos)
8. [Componentes Especializados SAO](#componentes-especializados-sao)
9. [Uso en Mobile vs Desktop](#uso-en-mobile-vs-desktop)
10. [Reglas de Implementación](#reglas-de-implementación)
11. [Representación de Entidades del Dominio](#representación-de-entidades-del-dominio)

---

## 🎯 Visión General

El **Sistema de Diseño SAO** es un conjunto unificado de tokens de diseño, componentes y catálogos compartidos entre las aplicaciones **Mobile (Flutter)** y **Desktop (Flutter)** del Sistema de Administración de Operaciones.

### Objetivos Principales

✅ **Consistencia Visual**: Misma apariencia en móvil y escritorio  
✅ **Fuente Única de Verdad**: Un solo lugar para colores, tipografías, espaciado  
✅ **Mantenibilidad**: Cambios centralizados se propagan automáticamente  
✅ **Escalabilidad**: Fácil agregar nuevos componentes siguiendo el sistema  

---

## 🏗️ Arquitectura del Sistema

### Estructura de Archivos

```
📁 SAO/
├── 📁 frontend_flutter/sao_windows/          # 📱 APP MÓVIL
│   └── lib/ui/
│       ├── theme/
│       │   ├── sao_colors.dart              # Colores centralizados
│       │   ├── sao_typography.dart          # Tipografía
│       │   ├── sao_spacing.dart             # Espaciado
│       │   ├── sao_radii.dart               # Radios de borde
│       │   ├── sao_shadows.dart             # Sombras
│       │   └── sao_theme.dart               # MaterialApp theme
│       └── widgets/
│           ├── sao_button.dart              # Botones
│           ├── sao_card.dart                # Tarjetas
│           ├── sao_field.dart               # Inputs
│           ├── sao_activity_card.dart       # Tarjeta de actividad
│           └── ...
│
└── 📁 desktop_flutter/sao_desktop/           # 🖥️ APP ESCRITORIO
    └── lib/ui/
        ├── sao_ui.dart                       # 🔥 Exporta TODO el sistema
        ├── theme/                            # (mismos archivos que mobile)
        └── widgets/                          # (mismos widgets que mobile)
```

### Importación Unificada

#### En Mobile (sao_windows):
```dart
import 'package:sao_windows/ui/theme/sao_colors.dart';
import 'package:sao_windows/ui/theme/sao_typography.dart';
import 'package:sao_windows/ui/widgets/sao_button.dart';
```

#### En Desktop (sao_desktop):
```dart
import 'package:sao_desktop/ui/sao_ui.dart';  // ⚡ Un solo import para TODO
```

El archivo `sao_ui.dart` exporta:
- 🎨 Theme (colores, tipografía, espaciado, radios, sombras)
- 🧩 Widgets (botones, cards, inputs, dropdowns, etc.)
- 📊 Catálogos globales (actividades, estados, riesgos, roles, proyectos)
- 🛠️ Helpers (formato, validación, plataforma)

---

## 🎨 Paleta de Colores

### Archivo: `sao_colors.dart`

#### 🔷 Grises (Escala Tailwind)

```dart
SaoColors.gray50   // #F8FAFC - Backgrounds muy claros
SaoColors.gray100  // #F1F5F9 - Backgrounds claros
SaoColors.gray200  // #E5E7EB - Bordes sutiles
SaoColors.gray300  // #CBD5E1 - Bordes normales
SaoColors.gray400  // #94A3B8 - Placeholders
SaoColors.gray500  // #64748B - Texto secundario
SaoColors.gray600  // #475569 - Texto terciario
SaoColors.gray700  // #334155 - Texto fuerte
SaoColors.gray800  // #1E293B - Texto muy fuerte
SaoColors.gray900  // #0F172A - Casi negro
```

**Uso:**
```dart
// ✅ CORRECTO
Container(color: SaoColors.gray100)
Text('Subtítulo', style: TextStyle(color: SaoColors.gray600))

// ❌ INCORRECTO
Container(color: Colors.grey.shade100)
Container(color: Color(0xFFF1F5F9))
```

---

#### 🔵 Primarios

```dart
SaoColors.primary           // #111827 - Negro profundo
SaoColors.primaryLight      // #374151 - Gris oscuro
SaoColors.onPrimary         // #FFFFFF - Blanco

// 🎯 Azul Marino Profundo (Color elegante de la app móvil)
SaoColors.actionPrimary     // #1A2B45 - Para botones principales
SaoColors.actionPrimaryLight // #2A3B55 - Hover en desktop
SaoColors.onActionPrimary   // #FFFFFF - Texto sobre actionPrimary
```

**Uso:**
```dart
// AppBar con color primary
AppBar(
  backgroundColor: SaoColors.actionPrimary,
  foregroundColor: SaoColors.onActionPrimary,
  title: Text('SAO'),
)

// Botón principal
SaoButton.primary(
  text: 'Guardar',
  onPressed: () {},
)
```

---

#### 🚦 Niveles de Riesgo (Homologados Mobile ↔ Desktop)

```dart
SaoColors.riskLow      // #16A34A 🟢 Verde - BAJO
SaoColors.riskMedium   // #F59E0B 🟡 Amarillo - MEDIO
SaoColors.riskHigh     // #F97316 🟠 Naranja - ALTO
SaoColors.riskPriority // #DC2626 🔴 Rojo - PRIORITARIO (📱 homologado)
SaoColors.riskCritical // Alias de riskPriority (compatibilidad)

// Backgrounds con opacidad (14%)
SaoColors.riskLowBg
SaoColors.riskMediumBg
SaoColors.riskHighBg
SaoColors.riskPriorityBg
```

**Helpers:**
```dart
// Obtener color según nivel de riesgo
Color color = SaoColors.getRiskColor('prioritario');  // Retorna riskPriority

// Obtener background según nivel
Color bg = SaoColors.getRiskBackground('alto');  // Retorna riskHighBg

// Traducir a español
String label = SaoColors.getRiskLabel('critical');  // Retorna 'PRIORITARIO'
```

**Uso:**
```dart
// Badge de riesgo
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: SaoColors.getRiskBackground(activity.risk),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    SaoColors.getRiskLabel(activity.risk),
    style: TextStyle(
      color: SaoColors.getRiskColor(activity.risk),
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

---

#### ⚠️ Alertas (Amarillo/Naranja)

```dart
SaoColors.alertBg      // #FFFBEB - Background amarillo claro
SaoColors.alertBorder  // #FDE68A - Borde amarillo
SaoColors.alertText    // #92400E - Texto marrón oscuro
```

**Uso:**
```dart
// Banner de advertencia
Container(
  color: SaoColors.alertBg,
  padding: EdgeInsets.all(12),
  child: Row(
    children: [
      Icon(Icons.warning_amber, color: SaoColors.alertText),
      SizedBox(width: 8),
      Text('Atención', style: TextStyle(color: SaoColors.alertText)),
    ],
  ),
)
```

---

#### ✅❌⚠️ℹ️ Estados (Success, Error, Warning, Info)

```dart
SaoColors.success   // #10B981 🟢 Verde - Operación exitosa
SaoColors.error     // #EF4444 🔴 Rojo - Error o validación fallida
SaoColors.warning   // #F59E0B 🟡 Amarillo - Advertencia
SaoColors.info      // #3B82F6 🔵 Azul - Información
```

**Uso:**
```dart
// SnackBar de éxito
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    backgroundColor: SaoColors.success,
    content: Text('Guardado exitosamente'),
  ),
);

// SnackBar de error
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    backgroundColor: SaoColors.error,
    content: Text('Error al guardar'),
  ),
);
```

---

#### 🏠 Superficie (Backgrounds, Borders)

```dart
SaoColors.surface       // #FFFFFF - Blanco (fondo de cards, paneles)
SaoColors.surfaceDim    // #F8FAFC (gray50) - Fondo de página
SaoColors.border        // #E5E7EB (gray200) - Bordes sutiles
SaoColors.borderStrong  // #CBD5E1 (gray300) - Bordes prominentes
```

---

#### 🚦 Estados Operativos (Workflow de SAO)

**⚠️ IMPORTANTE**: Estados operativos ≠ Niveles de riesgo

```dart
// Estados del flujo de trabajo
SaoColors.statusPendiente      // #F59E0B 🟡 Amarillo - Pendiente de acción
SaoColors.statusEnCampo        // #3B82F6 🔵 Azul - En campo/ejecución
SaoColors.statusEnValidacion   // #8B5CF6 🟣 Morado - En proceso de validación
SaoColors.statusAprobado       // #10B981 🟢 Verde - Aprobado/liberado
SaoColors.statusRechazado      // #EF4444 🔴 Rojo - Rechazado/bloqueado
SaoColors.statusBorrador       // #6B7280 ⚪ Gris - Borrador/sin enviar

// Backgrounds con opacidad
SaoColors.statusPendienteBg      // Amarillo suave
SaoColors.statusEnCampoBg        // Azul suave
SaoColors.statusEnValidacionBg   // Morado suave
SaoColors.statusAprobadoBg       // Verde suave
SaoColors.statusRechazadoBg      // Rojo suave
SaoColors.statusBorradorBg       // Gris suave
```

**Helpers:**
```dart
// Obtener color según estado operativo
Color color = SaoColors.getStatusColor('aprobado');  // Retorna statusAprobado

// Obtener background según estado
Color bg = SaoColors.getStatusBackground('en_validacion');  // Retorna statusEnValidacionBg

// Traducir a español
String label = SaoColors.getStatusLabel('aprobado');  // Retorna 'APROBADO'
```

**Uso:**
```dart
// Badge de estado operativo
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: SaoColors.getStatusBackground(activity.status),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        _getStatusIcon(activity.status),
        size: 14,
        color: SaoColors.getStatusColor(activity.status),
      ),
      SizedBox(width: 4),
      Text(
        SaoColors.getStatusLabel(activity.status),
        style: TextStyle(
          color: SaoColors.getStatusColor(activity.status),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    ],
  ),
)
```

**Uso:**
```dart
// Card con borde
Container(
  decoration: BoxDecoration(
    color: SaoColors.surface,
    border: Border.all(color: SaoColors.border),
    borderRadius: BorderRadius.circular(8),
  ),
  child: ...,
)
```

---

## ✍️ Tipografía

### Archivo: `sao_typography.dart`

Basado en **Inter** (sans-serif moderna y legible).

#### Jerarquía de Texto

```dart
// 📰 Títulos de Página
SaoTypography.pageTitle
// fontSize: 24, fontWeight: w700, color: gray900
// Uso: AppBar, encabezados principales

// 📄 Títulos de Sección
SaoTypography.sectionTitle
// fontSize: 18, fontWeight: w600, color: gray900
// Uso: Subtítulos, secciones dentro de página

// 🏷️ Títulos de Card
SaoTypography.cardTitle
// fontSize: 16, fontWeight: w600, color: gray900
// Uso: Título de SaoCard, diálogos

// 🏗️ JERARQUÍA OPERATIVA SAO (Proyecto > Frente > PK > Actividad)

SaoTypography.projectTitle
// fontSize: 20, fontWeight: w700, color: actionPrimary
// Uso: Nombre de proyecto (TMQ, TAP, TSNL)

SaoTypography.frontTitle
// fontSize: 18, fontWeight: w600, color: gray900
// Uso: Nombre de frente (Tenerías, Playa Grande)

SaoTypography.pkLabel
// fontSize: 16, fontWeight: w700, color: gray800, letterSpacing: 0.5
// Uso: Etiquetas PK (0+000, 1+250.50)

// 📝 Cuerpo (normal)
SaoTypography.body
// fontSize: 14, fontWeight: w400, color: gray700
// Uso: Texto estándar

// 📝 Cuerpo Mediano
SaoTypography.bodyMedium
// fontSize: 14, fontWeight: w500, color: gray700
// Uso: Texto con énfasis medio

// 📝 Cuerpo Pequeño
SaoTypography.bodySmall
// fontSize: 13, fontWeight: w400, color: gray600
// Uso: Texto secundario

// 🔤 Caption (pequeño)
SaoTypography.caption
// fontSize: 12, fontWeight: w400, color: gray500
// Uso: Metadatos, timestamps, hints

// 🏷️ Label
SaoTypography.label
// fontSize: 12, fontWeight: w600, color: gray700
// Uso: Labels de inputs, badges

// 🔘 Button
SaoTypography.button
// fontSize: 14, fontWeight: w600, color: gray900
// Uso: Texto de botones (aplicado automáticamente en SaoButton)
```

#### Ejemplos de Uso

```dart
// ✅ CORRECTO
Text('Dashboard', style: SaoTypography.pageTitle)
Text('Actividades Recientes', style: SaoTypography.sectionTitle)
Text('Caminamiento en TMQ', style: SaoTypography.cardTitle)
Text('Esta es una descripción normal', style: SaoTypography.body)
Text('Última actualización: hace 5 min', style: SaoTypography.caption)

// ❌ INCORRECTO
Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
Text('Título', style: AppTypography.pageTitle)  // ⚠️ No existe AppTypography
```

---

## 📐 Espaciado y Layout

### Archivo: `sao_spacing.dart`

Sistema de espaciado consistente basado en múltiplos de 4px.

```dart
SaoSpacing.xs           // 4px   - Espaciado mínimo
SaoSpacing.sm           // 8px   - Espaciado pequeño
SaoSpacing.md           // 12px  - Espaciado mediano
SaoSpacing.lg           // 16px  - Espaciado grande (DEFAULT)
SaoSpacing.xl           // 24px  - Espaciado extra grande
SaoSpacing.xxl          // 32px  - Espaciado doble extra

// Espaciado específico de contexto
SaoSpacing.cardPadding     // 16px - Padding interno de cards
SaoSpacing.pagePadding     // 24px - Padding de páginas
SaoSpacing.sectionSpacing  // 32px - Espacio entre secciones
```

#### Ejemplos

```dart
// Padding interno de card
Padding(
  padding: EdgeInsets.all(SaoSpacing.cardPadding),
  child: ...,
)

// Espacio entre widgets
SizedBox(height: SaoSpacing.lg)

// Espaciado de página
Padding(
  padding: EdgeInsets.all(SaoSpacing.pagePadding),
  child: ...,
)
```

---

### Archivo: `sao_radii.dart`

Radios de borde consistentes.

```dart
SaoRadii.sm      // 4px  - Badges, chips pequeños
SaoRadii.md      // 8px  - Cards, botones (DEFAULT)
SaoRadii.lg      // 12px - Paneles grandes
SaoRadii.xl      // 16px - Elementos destacados
SaoRadii.full    // 999px - Círculos perfectos
```

---

### Archivo: `sao_shadows.dart`

Sombras sutiles para profundidad.

```dart
SaoShadows.sm     // Sombra sutil (cards hover)
SaoShadows.md     // Sombra media (cards elevados)
SaoShadows.lg     // Sombra grande (modales)
```

---

### Archivo: `sao_layout.dart`

Breakpoints y helpers responsivos.

```dart
class SaoBreakpoints {
  static const mobile = 600;    // 0-600px: Mobile (1 columna)
  static const tablet = 1024;   // 600-1024px: Tablet (2 columnas)
  static const desktop = 1440;  // 1024-1440px: Desktop (3+ columnas)
  static const wide = 1920;     // 1440+: Wide desktop (4+ columnas)
}

class SaoLayout {
  // Detectar tipo de dispositivo
  static bool isMobile(BuildContext context) => 
    MediaQuery.of(context).size.width < SaoBreakpoints.mobile;
  
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= SaoBreakpoints.mobile && width < SaoBreakpoints.desktop;
  }
  
  static bool isDesktop(BuildContext context) => 
    MediaQuery.of(context).size.width >= SaoBreakpoints.desktop;
  
  static bool isWide(BuildContext context) => 
    MediaQuery.of(context).size.width >= SaoBreakpoints.wide;
  
  // Obtener número de columnas según ancho
  static int getColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < SaoBreakpoints.mobile) return 1;
    if (width < SaoBreakpoints.tablet) return 2;
    if (width < SaoBreakpoints.desktop) return 3;
    if (width < SaoBreakpoints.wide) return 4;
    return 6;
  }
  
  // Padding responsivo
  static double getPagePadding(BuildContext context) {
    if (isMobile(context)) return SaoSpacing.lg;
    if (isTablet(context)) return SaoSpacing.xl;
    return SaoSpacing.xxl;
  }
}
```

**Uso:**
```dart
// Layout responsivo
Padding(
  padding: EdgeInsets.all(SaoLayout.getPagePadding(context)),
  child: GridView.count(
    crossAxisCount: SaoLayout.getColumns(context),
    children: [...],
  ),
)

// Condicional por dispositivo
if (SaoLayout.isDesktop(context)) {
  // Mostrar sidebar
} else {
  // Mostrar drawer
}
```

---

## ⚡ Motion System (Animaciones)

### Archivo: `sao_motion.dart`

Sistema consistente de duraciones y curvas de animación.

```dart
class SaoMotion {
  // Duraciones estándar
  static const instant = Duration(milliseconds: 100);  // Feedback inmediato
  static const fast = Duration(milliseconds: 150);     // Transiciones rápidas
  static const normal = Duration(milliseconds: 250);   // Animaciones estándar
  static const slow = Duration(milliseconds: 400);     // Animaciones complejas
  static const slower = Duration(milliseconds: 600);   // Transiciones de página
  
  // Curvas de animación
  static const easeOut = Curves.easeOutCubic;          // Salida suave (default)
  static const easeIn = Curves.easeInCubic;            // Entrada suave
  static const easeInOut = Curves.easeInOutCubic;      // Suave ambos lados
  static const bounce = Curves.elasticOut;             // Efecto rebote
  static const sharp = Curves.easeOutExpo;             // Agresivo/rápido
}
```

**Uso:**
```dart
// Hover en card
AnimatedContainer(
  duration: SaoMotion.fast,
  curve: SaoMotion.easeOut,
  decoration: BoxDecoration(
    boxShadow: isHovered ? SaoShadows.md : SaoShadows.sm,
  ),
  child: ...,
)

// Transición de página
PageRouteBuilder(
  transitionDuration: SaoMotion.normal,
  pageBuilder: (context, animation, secondaryAnimation) => NextPage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation.drive(
        Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: SaoMotion.easeOut),
        ),
      ),
      child: child,
    );
  },
)

// Expansión de panel
AnimatedSize(
  duration: SaoMotion.normal,
  curve: SaoMotion.easeInOut,
  child: isExpanded ? ExpandedContent() : CollapsedContent(),
)
```

---

## 🧩 Componentes Compartidos

### SaoButton

Botones consistentes con 4 variantes.

```dart
// ✅ Primario (azul marino)
SaoButton.primary(
  text: 'Guardar',
  onPressed: () {},
  icon: Icons.save,
  isLoading: false,
)

// ⚪ Secundario (borde gris)
SaoButton.secondary(
  text: 'Cancelar',
  onPressed: () {},
)

// 🟢 Success
SaoButton.success(
  text: 'Aprobar',
  onPressed: () {},
  icon: Icons.check,
)

// 🔴 Danger
SaoButton.danger(
  text: 'Eliminar',
  onPressed: () {},
  icon: Icons.delete,
)
```

---

### SaoCard

Tarjetas con diseño consistente.

```dart
SaoCard(
  title: 'Estadísticas',
  child: Column(
    children: [
      Text('Contenido aquí'),
    ],
  ),
)

// Card sin título
SaoCard(
  child: Text('Contenido'),
)
```

---

### SaoField

Input de texto consistente.

```dart
SaoField(
  label: 'Nombre',
  hint: 'Ingrese su nombre completo',
  controller: _controller,
  validator: (value) => value?.isEmpty == true ? 'Requerido' : null,
  prefixIcon: Icons.person,
  maxLines: 1,
)
```

---

### SaoActivityCard

Tarjeta de actividad **UNIFICADA** (idéntica en mobile y desktop).

```dart
SaoActivityCard(
  title: 'Caminamiento en Playa Grande',
  pkLabel: 'PK-0001',
  subtitle: 'Frente Tenerías',
  location: 'Tláhuac',
  statusText: 'En progreso',
  statusIcon: Icons.pending,
  accentColor: SaoColors.riskMedium,
  badge: 'MEDIO',
  onTap: () {
    // Navegar a detalle
  },
)
```

**Características:**
- Barra vertical de color según riesgo/estado
- Título prominente + PK badge
- Metadatos: Frente, Municipio/Estado
- Footer con icono y texto de estado
- Hover sutil en desktop
- Estados: normal, selected, needsAttention

---

### SaoDropdown

Dropdown con diseño SAO.

```dart
SaoDropdown<String>(
  label: 'Proyecto',
  items: [
    DropdownMenuItem(value: 'tmq', child: Text('TMQ')),
    DropdownMenuItem(value: 'tlah', child: Text('TLAH')),
  ],
  value: _selectedProject,
  onChanged: (value) {
    setState(() => _selectedProject = value);
  },
)
```

---

### SaoPanel

Panel expansible con título.

```dart
SaoPanel(
  title: 'Información del Sistema',
  isExpanded: true,
  child: Column(
    children: [
      Text('Versión: 1.0.0'),
      Text('Build: 2026.02.18'),
    ],
  ),
)
```

---

### SaoBadge

Badge circular con contador.

```dart
Stack(
  children: [
    Icon(Icons.notifications),
    SaoBadge(count: 3),  // Muestra "3" en rojo
  ],
)
```

---

### SaoChip

Chip de categoría/filtro.

```dart
SaoChip(
  label: 'Caminamiento',
  color: SaoColors.primary,
  onTap: () {},
)
```

---

### SaoAlertCard

Tarjeta de alerta (warning).

```dart
SaoAlertCard(
  message: 'Esta actividad necesita revisión',
  icon: Icons.warning_amber,
)
```

---

### SaoEmptyState

Estado vacío con ilustración.

```dart
SaoEmptyState(
  icon: Icons.inbox_outlined,
  message: 'No hay actividades registradas',
  actionText: 'Crear nueva',
  onAction: () {},
)
```

---

## 🏗️ Componentes Especializados SAO

Componentes específicos del dominio ferroviario/operativo.

---

### SaoProjectSwitcher

Selector visual de proyecto con logo/color.

```dart
SaoProjectSwitcher(
  currentProject: 'tmq',
  projects: [
    ProjectItem(
      id: 'tmq',
      name: 'Tláhuac-Mixcoac-Quiroga',
      shortName: 'TMQ',
      color: SaoColors.actionPrimary,
      icon: Icons.train,
    ),
    ProjectItem(
      id: 'tap',
      name: 'Terminal Aérea-Pantitlán',
      shortName: 'TAP',
      color: Color(0xFF7C3AED),
      icon: Icons.flight,
    ),
    ProjectItem(
      id: 'tsnl',
      name: 'Toreo-San Lázaro',
      shortName: 'TSNL',
      color: Color(0xFFDC2626),
      icon: Icons.subway,
    ),
  ],
  onProjectChanged: (projectId) {
    // Cambiar contexto global
  },
)
```

**Características:**
- Dropdown con logos de proyecto
- Color distintivo por proyecto
- Shortname prominente (TMQ, TAP, TSNL)
- Animación al cambiar

---

### SaoPKIndicator

Indicador visual de posición PK (barra horizontal tipo corredor).

```dart
SaoPKIndicator(
  currentPK: 2.450,
  startPK: 0.0,
  endPK: 5.0,
  markers: [
    PKMarker(pk: 1.0, label: 'Estación 1'),
    PKMarker(pk: 3.5, label: 'Estación 2'),
  ],
  activities: [
    PKActivity(pk: 2.3, type: 'caminamiento', status: 'aprobado'),
    PKActivity(pk: 2.8, type: 'retiro', status: 'pendiente'),
  ],
)
```

**Características:**
- Barra horizontal con escala PK
- Indicador de posición actual
- Markers de estaciones/puntos importantes
- Miniaturas de actividades en su PK correspondiente
- Colores según estado

---

### SaoSyncIndicator

Indicador global de estado de sincronización offline/online.

```dart
// En AppBar o StatusBar
SaoSyncIndicator(
  isOnline: true,
  pendingCount: 3,
  lastSyncTime: DateTime.now().subtract(Duration(minutes: 5)),
  onTap: () {
    // Mostrar detalles de sincronización
  },
)
```

**Estados:**
- 🟢 Online + sincronizado
- 🟡 Online + cambios pendientes
- 🔴 Offline + cambios pendientes
- ⚪ Offline + sin cambios

**Características:**
- Animación pulsante cuando sincronizando
- Badge con contador de pendientes
- Timestamp de última sincronización
- Tap para ver cola de sincronización

---

### SaoRoleBadge

Badge institucional de rol/permiso.

```dart
SaoRoleBadge(
  role: 'coordinador',
  size: BadgeSize.medium,
)
```

**Roles:**
- 🔴 **ADMIN** - Rojo, ícono escudo
- 🔵 **COORDINADOR** - Azul, ícono estrella
- 🟢 **SUPERVISOR** - Verde, ícono check
- 🟡 **OPERATIVO** - Amarillo, ícono persona

**Características:**
- Color según rol
- Ícono representativo
- Tamaños: small, medium, large
- Hover tooltip con permisos

---

### SaoMetricCard

Tarjeta de métrica para Dashboard Desktop.

```dart
SaoMetricCard(
  title: 'Actividades Hoy',
  value: '24',
  subtitle: '+12% vs ayer',
  trend: MetricTrend.up,
  icon: Icons.assignment,
  color: SaoColors.info,
  onTap: () {
    // Navegar a detalle
  },
)
```

**Características:**
- Título + valor grande
- Subtítulo con comparación
- Trend indicator (up/down/neutral)
- Ícono contextual
- Hover con animación
- Sparkline opcional (gráfico mini)

---

### SaoTimelineItem

Elemento de timeline para historial de actividades.

```dart
SaoTimelineItem(
  timestamp: DateTime.now(),
  user: 'Juan Pérez',
  action: 'Aprobó actividad',
  details: 'Caminamiento en PK 2+450',
  status: 'aprobado',
  icon: Icons.check_circle,
  isFirst: true,
  isLast: false,
)
```

**Características:**
- Línea vertical conectora
- Avatar/ícono de usuario
- Timestamp relativo ("hace 5 min")
- Acción + detalles
- Color según tipo de acción

---

### SaoLiberacionViaCard

Tarjeta especializada para liberación de vía.

```dart
SaoLiberacionViaCard(
  frente: 'Tenerías',
  pkRange: PKRange(start: 0.0, end: 2.5),
  status: 'liberado',
  timestamp: DateTime.now(),
  approvedBy: 'Ing. García',
  activities: 24,
  evidences: 48,
  onViewDetails: () {},
)
```

**Estados:**
- 🟢 LIBERADO - Verde, vía lista
- 🔴 BLOQUEADO - Rojo, vía no disponible
- 🟡 EN PROCESO - Amarillo, liberación en curso

---

### SaoEvidenceGallery

Galería de evidencias fotográficas con geolocalización.

```dart
SaoEvidenceGallery(
  images: [
    EvidenceImage(
      url: 'https://...',
      thumbnail: 'https://...',
      timestamp: DateTime.now(),
      location: LatLng(19.4326, -99.1332),
      pk: 2.450,
      caption: 'Instalación de conexión principal',
    ),
  ],
  onImageTap: (image) {
    // Mostrar fullscreen con mapa
  },
)
```

**Características:**
- Grid responsivo
- Thumbnails con lazy loading
- Badge con PK en esquina
- Ícono de geolocalización
- Fullscreen viewer con mapa
- Zoom y pan

---

### SaoEvidenceViewer (Desktop Admin)

Visor completo de evidencias con caption obligatorio y metadata técnica.

```dart
SaoEvidenceViewer(
  evidence: EvidenceImage(
    url: 'https://...',
    thumbnail: 'https://...',
    timestamp: DateTime(2026, 2, 18, 19, 6),
    location: LatLng(19.4326, -99.1332),
    pk: 142.900,
    caption: 'Verificación de cableado en poste 142+900',
    user: 'María Hernández',
    device: 'Samsung Galaxy A52',
    accuracy: 8.5, // metros
  ),
  onOpenMap: () {
    // Abrir coordenadas en mapa
  },
  onDownload: () {
    // Descargar evidencia
  },
  onExportToReport: () {
    // Agregar a reporte
  },
)
```

**Características:**
- Foto grande con zoom/pan
- **Pie de foto obligatorio** (caption)
- Metadata técnica completa:
  * PK formateado (142+900)
  * Ubicación (Apaseo el Grande, Gto)
  * Timestamp (18 feb 2026 19:06)
  * Usuario capturista
  * GPS (coordenadas + precisión)
  * Dispositivo
- Validaciones visuales:
  * ✅ Caption presente
  * ✅ GPS presente
  * ⚠️ GPS impreciso (>15m)
  * ❌ Sin coordenadas
- Acciones admin:
  * Abrir en mapa
  * Descargar
  * Exportar a reporte
  * Solicitar recaptura (con motivo)

**Formato del pie de foto:**
```
📸 Verificación de cableado en poste 142+900

📏 PK 142+900 • Apaseo el Grande, Guanajuato
📅 18 feb 2026 19:06 • María Hernández
🌍 GPS: 19.4326, -99.1332 • Precisión: 8m ✅
📱 Samsung Galaxy A52
```

---

### SaoActivityTimeline (Desktop Admin)

Timeline completo de auditoría y trazabilidad por actividad.

```dart
SaoActivityTimeline(
  activityId: 'act_123',
  events: [
    AuditEvent(
      type: 'created',
      timestamp: DateTime.now().subtract(Duration(hours: 2)),
      actor: 'María Hernández',
      role: 'Operativo',
      details: 'Actividad creada offline en campo',
      icon: Icons.add_circle,
      color: SaoColors.statusBorrador,
    ),
    AuditEvent(
      type: 'synced',
      timestamp: DateTime.now().subtract(Duration(hours: 1, minutes: 45)),
      actor: 'Sistema',
      role: 'Automático',
      details: 'Sincronización completada desde dispositivo',
      icon: Icons.cloud_upload,
      color: SaoColors.info,
    ),
    AuditEvent(
      type: 'validation_requested',
      timestamp: DateTime.now().subtract(Duration(hours: 1)),
      actor: 'María Hernández',
      role: 'Operativo',
      details: 'Enviado a validación institucional',
      icon: Icons.send,
      color: SaoColors.statusEnValidacion,
    ),
    AuditEvent(
      type: 'correction_requested',
      timestamp: DateTime.now().subtract(Duration(minutes: 30)),
      actor: 'Juan Pérez',
      role: 'Supervisor',
      details: 'Solicitud de corrección: "Falta evidencia de conexión"',
      icon: Icons.comment,
      color: SaoColors.warning,
      metadata: {
        'before': 'En validación',
        'after': 'Pendiente corrección'
      },
    ),
    AuditEvent(
      type: 'edited',
      timestamp: DateTime.now().subtract(Duration(minutes: 15)),
      actor: 'María Hernández',
      role: 'Operativo',
      details: 'Evidencia adicional agregada',
      icon: Icons.edit,
      color: SaoColors.info,
    ),
    AuditEvent(
      type: 'approved',
      timestamp: DateTime.now(),
      actor: 'Ing. García',
      role: 'Coordinador',
      details: 'Actividad aprobada para liberación de vía',
      icon: Icons.check_circle,
      color: SaoColors.statusAprobado,
    ),
  ],
)
```

**Características:**
- Timeline vertical con conectores
- Cada evento muestra:
  * Tipo de acción (icono + color)
  * Actor (usuario + rol)
  * Timestamp relativo ("hace 2 horas") + absoluto
  * Detalles de la acción
  * Metadata opcional (antes/después)
- Tipos de eventos rastreados:
  * Creación (offline/online)
  * Sincronización
  * Ediciones
  * Comentarios/observaciones
  * Solicitud de validación
  * Solicitud de corrección
  * Aprobación/Rechazo
  * Generación de reportes
  * Cambios de catálogo relacionados
  * Conversión a evento crítico
- Filtros:
  * Por tipo de evento
  * Por actor/rol
  * Por rango de fechas
- Exportable a auditoría

---

### SaoValidationQueue (Desktop Admin)

Cola de actividades pendientes de validación con filtros administrativos.

```dart
SaoValidationQueue(
  filters: ValidationFilters(
    proyecto: 'tmq',
    frente: 'Tenerías',
    municipio: 'Apaseo el Grande',
    pkRange: PKRange(start: 140.0, end: 145.0),
    statusOperativo: ['pendiente', 'en_validacion'],
    riesgo: ['alto', 'prioritario'],
    fechaRange: DateRange(
      start: DateTime.now().subtract(Duration(days: 7)),
      end: DateTime.now(),
    ),
    banderas: ['sin_evidencia', 'sin_gps', 'caption_vacio'],
  ),
  onActivitySelected: (activity) {
    // Cargar en panel de detalle
  },
  sortBy: 'riesgo_desc', // prioritario primero
)
```

**Filtros fuertes:**
- **Contexto**: Proyecto / Frente / Municipio / Estado
- **PK**: Rango (ej: 140+000 a 145+000)
- **Estado operativo**: Pendiente / En validación / Aprobado / Rechazado / Borrador
- **Riesgo**: Bajo / Medio / Alto / Prioritario
- **Fecha**: Hoy / Esta semana / Este mes / Rango custom
- **Banderas de validación**:
  * ⚠️ Sin evidencia fotográfica
  * ⚠️ Sin GPS
  * ⚠️ Caption vacío
  * ⚠️ Campos obligatorios faltantes
  * ⚠️ Timestamp incoherente
- **Usuario**: Capturista específico

**Cada item de la cola usa `SaoActivityCard` IDÉNTICO al móvil** pero con señales administrativas adicionales:

```dart
SaoActivityCard(
  title: 'Caminamiento técnico de validación',
  pkLabel: '143+200',
  subtitle: 'Frente: Tramo 1 Apaseo Norte',
  location: 'Apaseo el Grande, Guanajuato',
  statusText: 'En validación',
  statusIcon: Icons.pending,
  accentColor: SaoColors.riskMedium,
  badge: 'MEDIO',
  needsAttention: true,
  
  // ⚡ Señales administrativas adicionales
  metadata: {
    'Evidencias': '3 fotos',
    'Documentos': '1 PDF',
    'GPS': '✅',
    'Caption': '❌ Faltante',
    'Usuario': 'María Hernández',
    'Hora': '19:06',
  },
  
  onTap: () {
    // Cargar en detalle técnico
  },
)
```

**Características:**
- **ADN visual IDÉNTICO** a la app móvil (mismo SaoActivityCard)
- Metadatos administrativos debajo del footer:
  * Contador de evidencias
  * Estado de GPS (✅/❌)
  * Validación de caption (✅/❌)
  * Usuario y hora de captura
- Orden inteligente:
  * **Prioritario** primero
  * Luego **Alto riesgo**
  * Luego por **hora de envío** a validación
- Badge visual de "Necesita atención" (needsAttention)
- Contador total: "12 actividades pendientes"

---

### SaoValidationDetail (Desktop Admin)

Panel de revisión técnica con validaciones automáticas.

```dart
SaoValidationDetail(
  activity: Activity(...),
  onApprove: (comments) async {
    // Aprobar con comentarios opcionales
  },
  onReject: (reason) async {
    // Rechazar con motivo obligatorio
  },
  onRequestCorrection: (comment) async {
    // Regresa a campo con comentario
  },
  onConvertToCritical: () async {
    // Convierte a evento crítico
  },
)
```

**Bloques de información:**

**1. Identidad**
```
🚂 Proyecto: TMQ (Tláhuac-Mixcoac-Quiroga)
📍 Frente: Tramo 1: Apaseo Norte
📏 PK: 143+200
📋 Tipo: Caminamiento técnico de validación
⚠️ Riesgo: MEDIO
```

**2. Captura**
```
👤 Usuario: María Hernández (Operativo)
📅 Fecha/Hora: 18 feb 2026, 19:06
📱 Dispositivo: Samsung Galaxy A52
🌐 Modo: Offline → Sincronizado 19:10
🌍 Coordenadas: 19.4326, -99.1332 (Precisión: 8m)
```

**3. Contenido**
```
📝 Descripción: [texto capturado en campo]
🏷️ Clasificación: Monitoreo electoral
📊 Campos dinámicos: [según catálogo]
```

**4. Validaciones automáticas (semáforos)**
```
✅ GPS presente y preciso (<15m)
✅ Hora coherente (dentro de horario operativo)
⚠️ Evidencia mínima (3/5 recomendadas)
❌ Caption vacío en 1 de 3 fotos
✅ Campos obligatorios completos
```

**5. Acciones principales**
```
[Aprobar]  [Rechazar]  [Solicitar corrección]  [→ Evento crítico]
```

- **Aprobar**: Cambia estado a `aprobado`, genera audit log
- **Rechazar**: Requiere motivo obligatorio (textarea), cambia a `rechazado`
- **Solicitar corrección**: Regresa a `pendiente` con comentario visible en móvil, notifica al capturista
- **Convertir a evento crítico**: Si la actividad amerita escalamiento

**6. Historial (Timeline embebido)**
Muestra últimos 5 eventos del `SaoActivityTimeline`

---

### SaoCatalogRequestCard (Desktop Admin)

Tarjeta de solicitud de cambio de catálogo.

```dart
SaoCatalogRequestCard(
  request: CatalogChangeRequest(
    id: 'req_456',
    tipo: 'add',
    entidad: 'activityType',
    payloadPropuesto: {
      'id': 'monitoreo_electoral',
      'nombre': 'Monitoreo electoral',
      'categoria': 'Civico',
      'riesgoDefault': 'medio',
    },
    motivo: 'Necesario para cobertura de elecciones 2026',
    evidencia: 'foto_solicitud.jpg',
    usuario: 'María Hernández',
    proyecto: 'TMQ',
    timestamp: DateTime.now().subtract(Duration(days: 2)),
    status: 'pendiente',
  ),
  onApprove: () {
    // Aprobar cambio, versionar catálogo, distribuir a móviles
  },
  onReject: (reason) {
    // Rechazar con motivo
  },
)
```

**Características:**
- Tipo de cambio:
  * **Agregar**: Nuevo tipo de actividad / frente / clasificación / campo
  * **Modificar**: Cambio en catálogo existente
  * **Eliminar**: Deprecar elemento (nunca eliminar, solo ocultar)
- Comparación visual "Antes vs Propuesta" (si es modificación)
- Evidencia adjunta (opcional)
- Motivo del solicitante (obligatorio)
- Aprobación genera:
  * Nueva versión de catálogo (vX.Y)
  * Audit log
  * Distribución a móviles en próximo sync
- Estados: Pendiente / Aprobado / Rechazado

---

### SaoReportGenerator (Desktop Admin)

Generador de reportes con plantillas.

```dart
SaoReportGenerator(
  template: 'reporte_diario',
  filters: ReportFilters(
    proyecto: 'TMQ',
    frente: 'Tramo 1',
    fechaRange: DateRange(
      start: DateTime.now().subtract(Duration(days: 1)),
      end: DateTime.now(),
    ),
    includeEvidencias: true,
    includePendientes: false, // solo aprobados
  ),
  onGenerate: (format) async {
    // Generar Word (.docx) o PDF
  },
)
```

**Plantillas disponibles:**
- **Reporte diario**: Actividades de hoy
- **Reporte por frente**: Todas las actividades de un frente
- **Reporte por PK**: Rango de progresivas
- **Bitácora de liberación**: Vías liberadas con firmas
- **Reporte de validación**: Actividades aprobadas/rechazadas por periodo

**Contenido del reporte:**
1. **Encabezado**:
   - Logo SAO
   - Proyecto + Frente
   - Fecha de generación
   - Rango de fechas cubierto
2. **Resumen ejecutivo**:
   - Total actividades
   - Por estado operativo
   - Por nivel de riesgo
   - Vías liberadas
3. **Detalle por actividad**:
   - Identidad (PK, tipo, descripción)
   - Usuario y fecha
   - Estado + aprobación
   - Evidencias fotográficas (con caption)
4. **Evidencias**:
   - Fotos con pie de foto completo
   - Coordenadas GPS
   - Timestamp
5. **Firmas**:
   - "Aprobado por: Ing. García (Coordinador)"
   - Fecha y hora de aprobación

**Versiones:**
- Cada reporte generado se guarda con versión
- No editable después de generado
- Auditoría de quién lo generó y cuándo

---

## 📱🖥️ Uso en Mobile vs Desktop

### Diferencia clave: ADN común, herramientas distintas

#### ✅ Lo que DEBE ser igual (ADN SAO)

**1. Tokens de diseño**
- SaoColors (incluyendo estados operativos y riesgos)
- SaoTypography (jerarquía operativa)
- SaoSpacing, SaoRadii, SaoShadows
- SaoMotion (animaciones)

**2. Componentes base**
- SaoButton (primario/secundario/success/danger)
- SaoCard (tarjetas consistentes)
- SaoBadge (contadores y etiquetas)
- SaoField (inputs)
- **SaoActivityCard** ⚡ **IDÉNTICO** en mobile y desktop

**3. Semántica del dominio**
- **Riesgo ≠ Estado operativo** (independientes)
- Nomenclatura: PK, Frente, Proyecto, Tramo
- Jerarquía: Proyecto > Frente > PK > Actividad

**4. Microcopy (textos)**
- "Pendiente validación"
- "En campo"
- "Vence hoy"
- "PRIORITARIO"
- "Liberado" / "Bloqueado"

#### ⚠️ Lo que DEBE ser diferente (por rol Admin/Coordinador)

**1. Layout**
- **Mobile**: Navegación bottom tabs, una actividad a la vez
- **Desktop**: Layout tipo "Centro de Validación" con 4 zonas simultáneas:
  * Sidebar (módulos)
  * Cola de validación (lista filtrable)
  * Detalle técnico (revisión)
  * Evidencias con pie de foto

**2. Herramientas administrativas**
- Trazabilidad completa (timeline de auditoría)
- Aprobación/rechazo con motivos
- Generación de reportes (Word/PDF)
- Gestión de catálogos (aprobar solicitudes)
- Bitácora de cambios
- Asignación de roles

**3. Información adicional**
- Metadata técnica (dispositivo, precisión GPS, modo offline/online)
- Validaciones automáticas (semáforos ✅/❌/⚠️)
- Historial completo de cambios
- Estadísticas agregadas

---

## 🖥️ Pantallas Desktop Admin

### Pantalla clave: "Validación de Operaciones"

Layout de 4 zonas fijas para revisión institucional.

```
╔════════════════════════════════════════════════════════════════════════════╗
║  SAO Desktop • 👤 Usuario Admin (Coordinador) • 🚂 Proyecto: TMQ           ║
║  🔔 12 pendientes • ⚠️ 8 prioritarias • 🕐 4 > 24hrs                        ║
╠═══════╦════════════════════╦════════════════════╦═══════════════════════════╣
║       ║                    ║                    ║                           ║
║  [A]  ║       [B]          ║       [C]          ║          [D]              ║
║       ║                    ║                    ║                           ║
║ SIDE  ║   COLA DE          ║   DETALLE          ║      EVIDENCIAS           ║
║ BAR   ║   VALIDACIÓN       ║   TÉCNICO          ║      + CAPTION            ║
║       ║                    ║                    ║                           ║
║ 🎯 Op.║   🔍 Filtros:      ║   1️⃣ IDENTIDAD     ║   📸 EVIDENCIAS (3/3)     ║
║ 📷 Ev.║   • TMQ            ║   🚂 TMQ           ║                           ║
║ 📄 Re.║   • Pendiente      ║   📍 Tramo 1       ║   [🖼️1] [🖼️2] [🖼️3]      ║
║ 📋 Tr.║   • Prioritario    ║   📏 PK 143+200    ║                           ║
║ 🏷️ Ca.║                    ║   📋 Caminamiento  ║   ════════════════        ║
║ 👥 Us.║   ┌──────────────┐ ║   ⚠️ MEDIO         ║   🖼️ FOTO GRANDE          ║
║       ║   │ 🔴 PRIORIT.  │ ║                    ║   [zoom/pan viewer]       ║
║       ║   │ Caminamiento │ ║   2️⃣ CAPTURA      ║                           ║
║ Badge:║   │ 143+200      │ ║   👤 María H.      ║   ════════════════        ║
║  12   ║   │ Tramo 1      │ ║   📅 18 feb 19:06  ║                           ║
║pending║   │ Apaseo GTO   │ ║   📱 Samsung A52   ║   📄 PIE DE FOTO:         ║
║       ║   │ En validación│ ║   📡 Offline→Sync  ║                           ║
║       ║   │ 3📷 GPS✅ ❌ │ ║   🌍 19.43,-99.13  ║   📸 Verificación de      ║
║       ║   │ María • 19:06│ ║      (±8m)         ║      cableado en poste    ║
║       ║   └──────────────┘ ║                    ║      143+200              ║
║       ║                    ║   3️⃣ CONTENIDO     ║                           ║
║       ║   ┌──────────────┐ ║   📝 [Descripción] ║   📏 PK 143+200           ║
║       ║   │ 🟠 ALTO      │ ║   🏷️ Monitoreo    ║   📍 Apaseo el Grande     ║
║       ║   │ Retiro       │ ║                    ║   📅 18 feb 2026 19:06    ║
║       ║   │ 142+900      │ ║   4️⃣ VALIDACIONES  ║   👤 María Hernández      ║
║       ║   │ ...          │ ║   ✅ GPS OK (<15m) ║   🌍 GPS: 19.43, -99.13   ║
║       ║   └──────────────┘ ║   ✅ Hora OK       ║      Precisión: 8m ✅     ║
║       ║                    ║   ⚠️ 3/5 evidencias║   📱 Samsung Galaxy A52   ║
║       ║   [12 más...]      ║   ❌ Caption vacío ║                           ║
║       ║                    ║   ✅ Campos OK     ║   [🗺️ Mapa] [⬇️ Descargar] ║
║       ║   📊 12 items      ║                    ║   [📄 → Reporte]          ║
║       ║                    ║   5️⃣ ACCIONES      ║                           ║
║       ║                    ║   [✅ Aprobar]     ║   ⚠️ Caption faltante     ║
║       ║                    ║   [❌ Rechazar]    ║   [📝 Solicitar caption]  ║
║       ║                    ║   [💬 Corrección]  ║                           ║
║       ║                    ║   [🚨 → Crítico]   ║                           ║
║       ║                    ║                    ║                           ║
║       ║                    ║   6️⃣ HISTORIAL     ║                           ║
║       ║                    ║   [Timeline 5+]    ║                           ║
╚═══════╩════════════════════╩════════════════════╩═══════════════════════════╝
```

**Flujo de trabajo:**
1. **Filtrar** actividades en Zona B (proyecto, estado, riesgo, banderas)
2. **Seleccionar** actividad de la cola → carga automáticamente en Zonas C y D
3. **Revisar** detalle técnico (identidad, captura, validaciones) en Zona C
4. **Inspeccionar** evidencias con caption y metadata en Zona D
5. **Decidir**: Aprobar / Rechazar / Solicitar corrección / Escalar a crítico
6. **Siguiente** actividad de la cola

---

#### Layout responsivo (4 columnas colapsables)

**Desktop Wide (>1920px):**
```
[Sidebar 200px] [Cola 400px] [Detalle 600px] [Evidencias 720px]
```

**Desktop Normal (1440-1920px):**
```
[Sidebar 180px] [Cola 350px] [Detalle 500px] [Evidencias 410px]
```

**Tablet Landscape (1024-1440px):**
```
[Sidebar collapse → drawer] [Cola 300px] [Detalle+Evidencias tabs]
```

**Tablet Portrait (<1024px):**
```
Mobile mode: una actividad a la vez con navegación por pestañas
```

---

#### Zona A: Sidebar (Módulos)

```dart
SaoSidebar(
  modules: [
    SidebarModule(
      icon: Icons.check_circle,
      label: 'Operaciones',
      route: '/validation',
      badge: 12, // pendientes
      isActive: true,
    ),
    SidebarModule(
      icon: Icons.photo_library,
      label: 'Evidencias',
      route: '/evidences',
    ),
    SidebarModule(
      icon: Icons.description,
      label: 'Reportes',
      route: '/reports',
    ),
    SidebarModule(
      icon: Icons.timeline,
      label: 'Trazabilidad',
      route: '/audit',
    ),
    SidebarModule(
      icon: Icons.category,
      label: 'Catálogos',
      route: '/catalogs',
      badge: 3, // solicitudes pendientes
    ),
    SidebarModule(
      icon: Icons.people,
      label: 'Usuarios',
      route: '/users',
    ),
  ],
)
```

**Módulos principales:**
1. **Operaciones** (Validación) - Pantalla principal
2. **Evidencias** - Galería completa con búsqueda
3. **Reportes** - Generación y historial
4. **Trazabilidad / Auditoría** - Timeline global
5. **Catálogos** - Gestión y solicitudes
6. **Usuarios / Roles** - Administración de accesos

---

#### Zona B: Cola de Validación (Lista)

Usa `SaoValidationQueue` con filtros fuertes.

**Filtros disponibles:**
```dart
ValidationFiltersBar(
  filters: {
    'Proyecto': Dropdown(['TMQ', 'TAP', 'TSNL']),
    'Frente': Dropdown(['Tramo 1', 'Tramo 2', 'Tramo 3']),
    'Municipio': Dropdown(['Apaseo el Grande', 'Celaya', ...]),
    'PK Rango': RangeInput(min: 0, max: 200),
    'Estado': MultiSelect(['Pendiente', 'En validación', 'Aprobado', 'Rechazado']),
    'Riesgo': MultiSelect(['Bajo', 'Medio', 'Alto', 'Prioritario']),
    'Fecha': DateRangePicker(),
    'Banderas': MultiSelect([
      '⚠️ Sin evidencia',
      '⚠️ Sin GPS',
      '⚠️ Caption vacío',
      '⚠️ Campos faltantes',
    ]),
    'Usuario': Dropdown([capturistas...]),
  },
)
```

**Cada item usa `SaoActivityCard` IDÉNTICO al móvil:**

```dart
// ⚡ MISMO COMPONENTE que usa la app móvil
SaoActivityCard(
  title: 'Caminamiento técnico de validación',
  pkLabel: '143+200',
  subtitle: 'Frente: Tramo 1 Apaseo Norte',
  location: 'Apaseo el Grande, Guanajuato',
  statusText: 'En validación',
  statusIcon: Icons.pending,
  accentColor: SaoColors.riskMedium,
  badge: 'MEDIO',
  needsAttention: true,
  
  // Metadata administrativa (solo desktop)
  adminMetadata: [
    MetadataChip(icon: Icons.photo, label: '3 fotos'),
    MetadataChip(icon: Icons.description, label: '1 doc'),
    MetadataChip(icon: Icons.gps_fixed, label: 'GPS ✅', color: SaoColors.success),
    MetadataChip(icon: Icons.edit_note, label: 'Caption ❌', color: SaoColors.error),
  ],
  captureInfo: 'María Hernández • 19:06',
  
  onTap: () {
    // Cargar en Zona C (detalle)
  },
)
```

**Orden de la cola:**
1. **PRIORITARIO** primero (rojo)
2. Alto riesgo (naranja)
3. Medio riesgo (amarillo)
4. Bajo riesgo (verde)
5. Dentro de cada nivel: por hora de envío (más antiguo primero)

**Header de la cola:**
```
📋 Cola de Trabajo
🔍 [Filtros activos: Proyecto=TMQ, Estado=Pendiente]
📊 12 actividades • 8 prioritarias • 4 > 24hrs
```

---

#### Zona C: Detalle Técnico (Revisión)

Usa `SaoValidationDetail` con validaciones automáticas.

**Layout del panel:**

```
┌─────────────────────────────────────┐
│ 1️⃣ IDENTIDAD                       │
│ 🚂 TMQ • 📍 Tramo 1 • 📏 143+200   │
│ 📋 Caminamiento técnico            │
│ ⚠️ MEDIO • 🟡 En validación        │
├─────────────────────────────────────┤
│ 2️⃣ CAPTURA                         │
│ 👤 María Hernández (Operativo)     │
│ 📅 18 feb 2026, 19:06              │
│ 📱 Samsung A52 • 📡 Offline→Sync   │
│ 🌍 19.4326, -99.1332 (±8m)         │
├─────────────────────────────────────┤
│ 3️⃣ CONTENIDO                       │
│ 📝 [Descripción del campo]         │
│ 🏷️ Clasificación: Monitoreo       │
│ 📊 [Campos dinámicos del catálogo] │
├─────────────────────────────────────┤
│ 4️⃣ VALIDACIONES                    │
│ ✅ GPS presente (<15m)             │
│ ✅ Hora coherente                  │
│ ⚠️ Evidencia: 3/5 recomendadas     │
│ ❌ Caption vacío en 1 foto         │
│ ✅ Campos obligatorios OK          │
├─────────────────────────────────────┤
│ 5️⃣ ACCIONES                        │
│ [✅ Aprobar]  [❌ Rechazar]         │
│ [💬 Solicitar corrección]          │
│ [🚨 → Evento crítico]              │
├─────────────────────────────────────┤
│ 6️⃣ HISTORIAL (últimos 5 eventos)  │
│ [Timeline embebido]                │
└─────────────────────────────────────┘
```

**Validaciones automáticas con semáforos:**

✅ **Verde**: Cumple
- GPS presente y preciso (<15m)
- Hora dentro horario operativo (6am-10pm)
- Todos los campos obligatorios llenos
- Evidencia mínima presente

⚠️ **Amarillo**: Advertencia (no bloquea)
- GPS impreciso (>15m pero <50m)
- Evidencia por debajo de recomendado
- Caption faltante en algunas fotos

❌ **Rojo**: Crítico (debe corregirse)
- Sin GPS
- Sin evidencia fotográfica mínima
- Campos obligatorios vacíos
- Timestamp incoherente (futuro o >7 días atrás)

**Acciones:**

1. **Aprobar** → Cambia a `aprobado`, genera audit log, notifica a capturista
2. **Rechazar** → Requiere motivo (modal con textarea), cambia a `rechazado`, notifica
3. **Solicitar corrección** → Regresa a `pendiente`, agrega comentario visible en móvil, notifica
4. **Convertir a evento crítico** → Escala a nivel prioritario, activa alertas

---

#### Zona D: Evidencias con Caption (Fotos + Metadata)

Usa `SaoEvidenceViewer` con metadata completa.

**Layout:**

```
┌───────────────────────────────────┐
│  📸 EVIDENCIAS (3/3)              │
│                                   │
│  [🖼️ Thumb 1] [🖼️ Thumb 2] [🖼️ 3] │
│                                   │
├───────────────────────────────────┤
│  🖼️ FOTO SELECCIONADA (grande)    │
│                                   │
│  [Visor con zoom/pan]             │
│                                   │
├───────────────────────────────────┤
│  📄 PIE DE FOTO                   │
│                                   │
│  📸 Verificación de cableado      │
│     en poste 142+900              │
│                                   │
│  📏 PK 143+200                    │
│  📍 Apaseo el Grande, Gto         │
│  📅 18 feb 2026 19:06             │
│  👤 María Hernández               │
│  🌍 GPS: 19.4326, -99.1332        │
│     Precisión: 8m ✅              │
│  📱 Samsung Galaxy A52            │
│                                   │
│  [🗺️ Abrir mapa]  [⬇️ Descargar]  │
│  [📄 Agregar a reporte]           │
│                                   │
│  ⚠️ Caption faltante              │
│  [📝 Solicitar caption]           │
└───────────────────────────────────┘
```

**Formato del pie de foto obligatorio:**

```
📸 [Caption del capturista]

📏 PK [progresiva]
📍 [Municipio, Estado]
📅 [Fecha hora] • [Usuario]
🌍 GPS: [lat, lon] • Precisión: [metros] [✅/⚠️/❌]
📱 [Dispositivo]
```

**Validación del caption:**
- ✅ **Verde**: Caption presente y >10 caracteres
- ⚠️ **Amarillo**: Caption muy corto (<10 caracteres)
- ❌ **Rojo**: Caption vacío

Si caption faltante:
- Botón **"Solicitar caption"** → regresa a móvil con notificación
- Se marca con bandera en cola de validación

**Acciones sobre evidencia:**
- **Abrir en mapa**: Muestra coordenadas en mapa interactivo
- **Descargar**: Descarga foto original
- **Agregar a reporte**: Marca para incluir en próximo reporte
- **Solicitar recaptura**: Si foto borrosa o incorrecta (requiere motivo)

---

### Pantalla: Trazabilidad / Auditoría

Vista de timeline completo por actividad o por frente.

```dart
AuditPage(
  mode: 'activity', // o 'frente'
  entityId: 'act_123',
  timeline: SaoActivityTimeline(...),
  filters: TimelineFilters(
    eventTypes: ['edited', 'approved', 'rejected'],
    actorRole: 'coordinador',
    dateRange: DateRange(...),
  ),
  onExport: () {
    // Exportar auditoría a Excel/PDF
  },
)
```

**Eventos rastreados:**
1. **Creación**: Offline/Online, dispositivo, ubicación
2. **Sincronización**: Timestamp, tamaño de datos
3. **Ediciones**: Campo modificado, antes/después, quién
4. **Comentarios**: Usuario, rol, texto
5. **Solicitud de validación**: Cuándo se envió a revisión
6. **Solicitud de corrección**: Motivo, quién la solicitó
7. **Aprobación/Rechazo**: Decisión, motivo, coordinador
8. **Generación de reportes**: Quién, cuándo, qué reporte
9. **Cambios de catálogo relacionados**: Qué se modificó
10. **Conversión a evento crítico**: Timestamp, escalador

**Filtros:**
- Por tipo de evento
- Por actor (usuario)
- Por rol (operativo/supervisor/coordinador)
- Por rango de fechas
- Por proyecto/frente

**Exportación:**
- Excel: Tabla con todos los eventos
- PDF: Timeline visual con descripción

---

### Pantalla: Reportes

Generador de reportes con plantillas.

```dart
ReportsPage(
  templates: [
    ReportTemplate(
      id: 'diario',
      nombre: 'Reporte Diario',
      descripcion: 'Actividades de hoy por proyecto',
      icon: Icons.today,
    ),
    ReportTemplate(
      id: 'frente',
      nombre: 'Reporte por Frente',
      descripcion: 'Todas las actividades de un frente',
      icon: Icons.location_on,
    ),
    ReportTemplate(
      id: 'pk_range',
      nombre: 'Reporte por PK',
      descripcion: 'Actividades en rango de progresivas',
      icon: Icons.linear_scale,
    ),
    ReportTemplate(
      id: 'liberacion',
      nombre: 'Bitácora de Liberación',
      descripcion: 'Vías liberadas con firmas institucionales',
      icon: Icons.check_circle,
    ),
    ReportTemplate(
      id: 'validacion',
      nombre: 'Reporte de Validación',
      descripcion: 'Actividades aprobadas/rechazadas por periodo',
      icon: Icons.gavel,
    ),
  ],
  onGenerate: (template, filters) {
    // Generar reporte
  },
)
```

**Flujo de generación:**
1. Seleccionar plantilla
2. Configurar filtros:
   - Proyecto / Frente
   - Rango de fechas
   - PK rango (opcional)
   - Estados a incluir
   - ¿Incluir evidencias fotográficas?
   - ¿Incluir actividades pendientes? (generalmente NO)
3. Vista previa (opcional)
4. Generar:
   - **Word (.docx)**: Editable para ajustes finales
   - **PDF**: Versión final sellada
5. Guardar versión en historial con metadata:
   - Quién lo generó
   - Cuándo
   - Qué filtros usó
   - Hash del contenido (inmutabilidad)

**Contenido del reporte:**
1. **Portada**:
   - Logo SAO
   - Título del reporte
   - Proyecto + Frente
   - Fecha de generación
   - Generado por: [Usuario]
2. **Resumen ejecutivo**:
   - Tabla de métricas
   - Total actividades
   - Por estado operativo
   - Por nivel de riesgo
   - Vías liberadas
3. **Detalle por actividad**:
   - Tabla ordenada por PK
   - Columnas: PK, Tipo, Usuario, Fecha, Estado, Riesgo
   - Descripción
   - Evidencias (si aplica)
4. **Evidencias fotográficas**:
   - 1-2 fotos por página
   - Caption completo
   - Metadata: PK, GPS, usuario, timestamp
5. **Firmas institucionales**:
   - "Elaboró: [Operativo]"
   - "Revisó: [Supervisor]"
   - "Aprobó: [Coordinador]"
   - Fecha y hora
6. **Anexos** (si aplica):
   - Plano de ubicación (mapa con todos los PK)
   - Gráficas de progreso

**Historial de reportes:**
- Lista de todos los reportes generados
- Filtros: Por plantilla, proyecto, fecha
- Re-descarga de reportes anteriores (inmutables)
- Metadata de quién lo generó

---

### Pantalla: Gestión de Catálogos

Aprobación de solicitudes de cambio.

```dart
CatalogsPage(
  pendingRequests: [
    CatalogChangeRequest(...),
    ...
  ],
  catalogs: [
    Catalog(
      id: 'activityTypes',
      nombre: 'Tipos de Actividad',
      version: '2.3.1',
      lastUpdate: DateTime.now().subtract(Duration(days: 15)),
      itemCount: 47,
    ),
    Catalog(
      id: 'fronts',
      nombre: 'Frentes',
      version: '1.8.0',
      itemCount: 12,
    ),
    ...
  ],
  onApproveRequest: (request) {
    // Aprobar, versionar catálogo, distribuir
  },
  onRejectRequest: (request, reason) {
    // Rechazar con motivo
  },
)
```

**Solicitudes pendientes (cola):**

Cada request usa `SaoCatalogRequestCard`:

```
┌─────────────────────────────────────┐
│ 📝 SOLICITUD DE CATÁLOGO            │
│                                     │
│ Tipo: ➕ AGREGAR                    │
│ Entidad: Tipo de Actividad         │
│                                     │
│ 📋 Propuesta:                       │
│ Nombre: "Monitoreo electoral"      │
│ Categoría: "Cívico"                │
│ Riesgo default: "Medio"            │
│                                     │
│ 💬 Motivo:                          │
│ "Necesario para cobertura de       │
│  elecciones 2026"                  │
│                                     │
│ 👤 Solicitante: María Hernández    │
│ 🚂 Proyecto: TMQ                   │
│ 📅 hace 2 días                     │
│                                     │
│ 📎 Evidencia: [foto_solicitud.jpg] │
│                                     │
│ [✅ Aprobar]  [❌ Rechazar]         │
└─────────────────────────────────────┘
```

**Flujo de aprobación:**
1. Revisar propuesta
2. Si es modificación: Ver comparación "Antes vs Después"
3. Aprobar:
   - Actualizar catálogo
   - Incrementar versión (v2.3.1 → v2.4.0)
   - Generar audit log
   - Marcar para distribución en próximo sync
   - Notificar al solicitante
4. Rechazar:
   - Requiere motivo (textarea)
   - Notificar al solicitante con explicación

**Catálogos disponibles:**
- **Tipos de Actividad** (activityTypes)
- **Frentes** (fronts)
- **Clasificaciones** (classifications)
- **Estados/Municipios** (locations)
- **Campos dinámicos** (dynamicFields)

**Versioning:**
- Versionado semántico: `vMAJOR.MINOR.PATCH`
- **MAJOR**: Cambio estructural (rompe compatibilidad)
- **MINOR**: Agregar elementos nuevos
- **PATCH**: Correcciones menores

**Distribución:**
- Catálogo versionado se empaqueta
- En próximo sync, móviles descargan:
  * Si es MAJOR: descarga completa
  * Si es MINOR/PATCH: descarga incremental (solo cambios)
- Móvil compara versión local vs servidor
- Si hay diferencia: descarga y actualiza local

---

#### Estructura de Imports

```dart
// En cualquier archivo de features/
import '../../ui/theme/sao_colors.dart';
import '../../ui/theme/sao_typography.dart';
import '../../ui/theme/sao_spacing.dart';
import '../../ui/widgets/sao_button.dart';
import '../../ui/widgets/sao_card.dart';
```

#### Ejemplo Completo: wizard_step_context.dart

```dart
import 'package:flutter/material.dart';
import '../../ui/theme/sao_colors.dart';
import '../../ui/theme/sao_typography.dart';
import '../../ui/theme/sao_spacing.dart';
import '../../ui/widgets/sao_field.dart';

class WizardStepContext extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaoColors.surfaceDim,
      appBar: AppBar(
        backgroundColor: SaoColors.actionPrimary,
        foregroundColor: SaoColors.onActionPrimary,
        title: Text('Contexto de Actividad'),
      ),
      body: Padding(
        padding: EdgeInsets.all(SaoSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Información Básica', style: SaoTypography.sectionTitle),
            SizedBox(height: SaoSpacing.lg),
            
            // Campo con diseño SAO
            SaoField(
              label: 'PK',
              hint: 'Ej: 0+000',
              controller: _pkController,
            ),
            
            SizedBox(height: SaoSpacing.md),
            
            // Badge de riesgo
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: SaoSpacing.sm,
                vertical: SaoSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: SaoColors.getRiskBackground('alto'),
                borderRadius: BorderRadius.circular(SaoRadii.sm),
              ),
              child: Text(
                SaoColors.getRiskLabel('alto'),
                style: SaoTypography.label.copyWith(
                  color: SaoColors.getRiskColor('alto'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Desktop (sao_desktop)

#### Estructura de Imports (UN SOLO IMPORT)

```dart
// En cualquier archivo de features/
import '../../ui/sao_ui.dart';  // ⚡ Importa TODO el sistema
```

#### Ejemplo Completo: validation_page_simple.dart

```dart
import 'package:flutter/material.dart';
import '../../ui/sao_ui.dart';  // 🔥 Un solo import

class ValidationPageSimple extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaoColors.surfaceDim,
      body: Column(
        children: [
          // Header con color actionPrimary
          Container(
            color: SaoColors.actionPrimary,
            padding: EdgeInsets.all(SaoSpacing.pagePadding),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: SaoColors.onActionPrimary),
                SizedBox(width: SaoSpacing.lg),
                Text(
                  'Validación de Actividades',
                  style: SaoTypography.pageTitle.copyWith(
                    color: SaoColors.onActionPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de actividades
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(SaoSpacing.lg),
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: SaoSpacing.lg),
                  child: SaoActivityCard(
                    title: 'Caminamiento en TMQ',
                    pkLabel: 'PK-0001',
                    subtitle: 'Frente Tenerías',
                    location: 'Tláhuac',
                    statusText: 'Pendiente validación',
                    statusIcon: Icons.pending,
                    accentColor: SaoColors.riskMedium,
                    badge: 'MEDIO',
                    needsAttention: true,
                    onTap: () {},
                  ),
                );
              },
            ),
          ),
          
          // Footer con botones
          Container(
            padding: EdgeInsets.all(SaoSpacing.lg),
            decoration: BoxDecoration(
              color: SaoColors.surface,
              border: Border(top: BorderSide(color: SaoColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SaoButton.secondary(
                  text: 'Rechazar',
                  onPressed: () {},
                ),
                SizedBox(width: SaoSpacing.md),
                SaoButton.success(
                  text: 'Aprobar',
                  icon: Icons.check,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## ⚠️ Reglas de Implementación

### ✅ SÍ Hacer

```dart
// ✅ Usar tokens de SaoColors
Container(color: SaoColors.gray100)
Text('Texto', style: TextStyle(color: SaoColors.primary))

// ✅ Usar SaoTypography
Text('Título', style: SaoTypography.pageTitle)

// ✅ Usar SaoSpacing
Padding(padding: EdgeInsets.all(SaoSpacing.lg))

// ✅ Usar componentes SAO
SaoButton.primary(text: 'Guardar', onPressed: () {})
SaoField(label: 'Nombre', controller: _controller)

// ✅ Usar helpers de color de riesgo
Container(color: SaoColors.getRiskColor('alto'))

// ✅ Usar catálogos globales
ActivityCatalog.caminamiento
StatusCatalog.aprobado
RiskCatalog.prioritario
```

---

### ❌ NO Hacer

```dart
// ❌ NO usar colores hardcodeados
Container(color: Color(0xFF1A2B45))  // ⚠️ Usar SaoColors.actionPrimary
Container(color: Color.fromRGBO(26, 43, 69, 1))

// ❌ NO usar Colors.* directamente
Container(color: Colors.blue)  // ⚠️ Usar SaoColors.primary o SaoColors.info
Text('Texto', style: TextStyle(color: Colors.grey.shade600))  // ⚠️ SaoColors.gray600
Icon(Icons.check, color: Colors.green)  // ⚠️ SaoColors.success

// ❌ NO usar TextStyle sin SaoTypography
Text('Título', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
// ⚠️ Usar: Text('Título', style: SaoTypography.pageTitle)

// ❌ NO usar padding hardcodeado
Padding(padding: EdgeInsets.all(16))  // ⚠️ Usar SaoSpacing.lg o SaoSpacing.cardPadding

// ❌ NO usar botones nativos de Flutter
ElevatedButton(child: Text('Guardar'), onPressed: () {})
// ⚠️ Usar: SaoButton.primary(text: 'Guardar', onPressed: () {})

// ❌ NO crear componentes custom sin seguir el sistema
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [BoxShadow(...)],
  ),
  child: ...,
)
// ⚠️ Usar: SaoCard(child: ...)

// ❌ NO usar strings hardcodeados para catálogos
if (activity.status == 'aprobado') { ... }
// ⚠️ Usar: if (activity.status == StatusCatalog.aprobado) { ... }

// ❌ NO importar AppColors o AppTypography (legacy)
import '../../ui/theme/app_colors.dart';  // ⚠️ No existe
import '../../ui/theme/app_typography.dart';  // ⚠️ Usar sao_typography.dart
```

---

## 📊 Catálogos Globales

Los catálogos son **fuentes únicas de verdad** para datos del dominio.

### ActivityCatalog

```dart
ActivityCatalog.caminamiento
ActivityCatalog.retiro
ActivityCatalog.conexion
ActivityCatalog.inspeccion
// ... etc
```

### StatusCatalog

```dart
StatusCatalog.pendiente
StatusCatalog.enProgreso
StatusCatalog.aprobado
StatusCatalog.rechazado
StatusCatalog.enRevision
```

### RiskCatalog

```dart
RiskCatalog.bajo          // 'low'
RiskCatalog.medio         // 'medium'
RiskCatalog.alto          // 'high'
RiskCatalog.prioritario   // 'critical' (📱 homologado)
```

### RolesCatalog

```dart
RolesCatalog.admin
RolesCatalog.coordinador
RolesCatalog.supervisor
RolesCatalog.operador
```

### ProjectsCatalog

```dart
ProjectsCatalog.tmq       // 'Tláhuac-Mixcoac-Quiroga'
ProjectsCatalog.tlah      // 'Tláhuac'
ProjectsCatalog.mxc       // 'Mixcoac'
```

---

## �️ Arquitectura de Datos (Backend)

Para soportar el sistema Admin Desktop, se requieren las siguientes entidades:

### 1. Activity (con extensiones admin)

```dart
class Activity {
  String id;
  String proyecto;
  String frente;
  double pk;
  String tipo;
  String descripcion;
  
  // Estados
  String statusOperativo; // pendiente/en_campo/en_validacion/aprobado/rechazado/borrador
  String riesgo;          // bajo/medio/alto/prioritario
  
  // Captura
  String usuarioId;
  DateTime timestamp;
  String dispositivo;
  bool capturaOffline;
  DateTime? syncTimestamp;
  
  // Geolocalización
  double? latitude;
  double? longitude;
  double? gpsAccuracy;
  
  // Validaciones admin
  Map<String, bool> validaciones; // {gps_ok, caption_ok, campos_ok, etc.}
  
  // Relaciones
  List<String> evidenciaIds;
  List<String> documentoIds;
  String? auditLogId;
}
```

---

### 2. Evidence (con caption obligatorio)

```dart
class Evidence {
  String id;
  String activityId;
  
  // Archivo
  String url;
  String thumbnailUrl;
  int fileSize;
  
  // Caption (PIE DE FOTO)
  String caption; // ⚡ OBLIGATORIO para validación
  
  // Metadata
  DateTime timestamp;
  String usuario;
  String dispositivo;
  
  // Geolocalización
  double? latitude;
  double? longitude;
  double? gpsAccuracy;
  double? pk;
  
  // Validación
  bool captionApproved;
  String? captionRejectionReason;
}
```

**Regla de negocio**: Una evidencia sin caption **no puede ser aprobada** para reportes institucionales.

---

### 3. ActivityAuditLog (Timeline completo)

```dart
class ActivityAuditLog {
  String id;
  String activityId;
  List<AuditEvent> events;
}

class AuditEvent {
  String id;
  String tipo; // created, synced, edited, commented, correction_requested, approved, rejected, critical_escalation, etc.
  DateTime timestamp;
  
  // Actor
  String? usuarioId;
  String? rol; // operativo/supervisor/coordinador/sistema
  
  // Detalle
  String descripcion;
  Map<String, dynamic>? metadata; // {field: 'descripcion', before: '...', after: '...'}
  
  // UI
  String icon; // Icons name
  String colorKey; // SaoColors key
}
```

**Eventos rastreados:**
- `created` - Actividad creada (offline/online)
- `synced` - Sincronización completada
- `edited` - Campo modificado
- `evidence_added` - Evidencia agregada
- `evidence_removed` - Evidencia eliminada
- `commented` - Comentario/observación
- `validation_requested` - Enviado a validación
- `correction_requested` - Solicitada corrección
- `approved` - Aprobado para liberación
- `rejected` - Rechazado con motivo
- `critical_escalation` - Convertido a evento crítico
- `report_generated` - Incluido en reporte
- `catalog_changed` - Catálogo relacionado actualizado

---

### 4. Report (Versioned & Immutable)

```dart
class Report {
  String id;
  String templateId; // diario, frente, pk_range, liberacion, validacion
  String version; // hash SHA-256 para inmutabilidad
  
  // Metadata
  DateTime generatedAt;
  String generadoPorUsuarioId;
  String generadoPorNombre;
  
  // Filtros aplicados
  Map<String, dynamic> filters; // {proyecto, frente, fechas, etc.}
  
  // Contenido
  String titulo;
  Map<String, dynamic> resumenEjecutivo;
  List<String> activityIds; // actividades incluidas
  
  // Archivos generados
  String? docxUrl;
  String? pdfUrl;
  
  // Firmas institucionales
  Firma? elaboro;
  Firma? reviso;
  Firma? aprobo;
  
  // Inmutabilidad
  bool isSealed; // true después de generar PDF
}

class Firma {
  String usuarioId;
  String nombre;
  String rol;
  DateTime timestamp;
}
```

**Regla de negocio**: 
- Report se guarda ANTES de generar archivos (draft)
- Al generar PDF final: `isSealed = true` → inmutable
- No se puede editar después de sealed
- Versión (hash) garantiza que el contenido nunca cambió

---

### 5. CatalogChangeRequest (Workflow de aprobación)

```dart
class CatalogChangeRequest {
  String id;
  
  // Tipo de cambio
  String tipo; // add, update, delete (deprecate)
  String entidad; // activityType, front, classification, field
  
  // Propuesta
  Map<String, dynamic> payloadPropuesto;
  Map<String, dynamic>? payloadAnterior; // si es update
  
  // Contexto
  String motivo;
  String? evidenciaUrl; // opcional
  
  // Solicitante
  String usuarioId;
  String proyecto;
  DateTime timestamp;
  
  // Estado
  String status; // pendiente, aprobado, rechazado
  
  // Aprobación/Rechazo
  String? aprobadorUsuarioId;
  DateTime? aprobadoRechazadoAt;
  String? motivoRechazo;
  
  // Distribución
  bool distribuidoAMoviles;
  DateTime? distribuidoAt;
}
```

---

### 6. CatalogVersion (Distribución a móviles)

```dart
class CatalogVersion {
  String catalogId; // activityTypes, fronts, classifications, etc.
  String version; // v2.4.0 (semver)
  DateTime createdAt;
  
  // Contenido
  Map<String, dynamic> data; // estructura del catálogo
  
  // Distribución
  bool isIncremental; // true = solo cambios, false = completo
  List<String>? changeIds; // IDs de elementos modificados (si incremental)
  
  // Metadata
  int itemCount;
  String? changelogUrl; // archivo con lista de cambios
}
```

**Distribución incremental:**
- **Mobile sync** compara versión local vs server
- Si diferencia MAJOR: descarga completa
- Si diferencia MINOR/PATCH: descarga solo `changeIds`
- Aplica cambios localmente y actualiza versión

---

### 7. Relaciones entre entidades

```
Activity 1───N Evidence (caption obligatorio)
Activity 1───1 ActivityAuditLog (timeline)
Activity N───M Report (versionado)
User 1───N CatalogChangeRequest
CatalogVersion 1───N CatalogChangeRequest (aprobados)
```

---

### 8. Reglas de negocio críticas

**Validación de Actividad (Admin):**
1. **GPS presente**: `latitude != null && longitude != null`
2. **GPS preciso**: `gpsAccuracy < 15` ✅, `15-50` ⚠️, `>50` ❌
3. **Caption completo**: Todas las evidencias tienen `caption.length > 10`
4. **Campos obligatorios**: Según catálogo de tipo de actividad
5. **Timestamp coherente**: No futuro, no >7 días atrás

**Aprobación:**
- Solo puede aprobar: **Coordinador** o superior
- Requiere pasar validaciones mínimas:
  * ✅ GPS presente
  * ✅ Campos obligatorios completos
  * ⚠️ Caption puede faltar (con bandera)
- Genera `AuditEvent` tipo `approved`
- Cambia `statusOperativo` a `aprobado`

**Rechazo:**
- Requiere **motivo obligatorio** (>20 caracteres)
- Genera `AuditEvent` tipo `rejected`
- Cambia `statusOperativo` a `rechazado`
- Notifica a capturista con motivo

**Solicitud de corrección:**
- Requiere **comentario** (guía de qué corregir)
- Genera `AuditEvent` tipo `correction_requested`
- Cambia `statusOperativo` a `pendiente`
- Notifica a capturista
- **Móvil**: Muestra comentario en detalle de actividad

**Generación de reportes:**
- Solo actividades con `statusOperativo = aprobado` (excepto plantilla "validacion")
- Si `includeEvidencias = true`: valida que todas tengan caption
- Genera versión inmutable (hash SHA-256)
- Al generar PDF: `isSealed = true` → no editable

**Catálogos:**
- Solicitud solo puede crear: **Operativo en campo**
- Aprobación solo puede hacer: **Coordinador**
- Al aprobar: incrementa versión, marca para distribución
- Sync automático cada 4 horas o al iniciar app móvil
- Móvil descarga incremental si versión diferente

---

## �🚀 Migración de Código Legacy

### Reemplazos Comunes

| ❌ Antes (Legacy) | ✅ Después (SAO) |
|------------------|------------------|
| `Colors.grey.shade600` | `SaoColors.gray600` |
| `Colors.orange.shade700` | `SaoColors.warning` |
| `Colors.red.shade700` | `SaoColors.error` |
| `Colors.green.shade600` | `SaoColors.success` |
| `Colors.blue` | `SaoColors.info` |
| `Color(0xFF1E3A8A)` | `SaoColors.actionPrimary` |
| `Color(0xFFE5E7EB)` | `SaoColors.border` |
| `Colors.white` | `SaoColors.surface` |
| `AppTypography.pageTitle` | `SaoTypography.pageTitle` |
| `ElevatedButton(...)` | `SaoButton.primary(...)` |
| `TextField(...)` | `SaoField(...)` |

---

## 🔍 Verificación de Migración

### Checklist

- [ ] ✅ NO hay `Color(0x...)` hardcodeados
- [ ] ✅ NO hay `Colors.*` de Flutter (excepto `Colors.transparent`)
- [ ] ✅ NO hay `AppColors` o `AppTypography` (legacy)
- [ ] ✅ USO `SaoColors.*` para todos los colores
- [ ] ✅ USO `SaoTypography.*` para todos los estilos de texto
- [ ] ✅ USO `SaoSpacing.*` para padding/margin
- [ ] ✅ USO `SaoButton.*` para botones
- [ ] ✅ USO `SaoField` para inputs
- [ ] ✅ USO `SaoCard` para tarjetas
- [ ] ✅ USO `SaoActivityCard` para listas de actividades
- [ ] ✅ USO catálogos globales (StatusCatalog, RiskCatalog, etc.)

---

## 🏗️ Representación de Entidades del Dominio

Guía visual de cómo representar entidades clave del SAO.

---

### 🚂 Proyecto

**Componente Principal**: `SaoProjectSwitcher`

**Representación Visual:**
- Shortname en **SaoTypography.projectTitle** (TMQ, TAP, TSNL)
- Color distintivo por proyecto
- Ícono representativo (tren, avión, metro)
- Nombre completo debajo

**Ejemplo:**
```dart
Container(
  padding: EdgeInsets.all(SaoSpacing.md),
  decoration: BoxDecoration(
    color: ProjectsCatalog.getColor('tmq'),
    borderRadius: BorderRadius.circular(SaoRadii.md),
  ),
  child: Column(
    children: [
      Icon(Icons.train, color: SaoColors.onActionPrimary, size: 32),
      SizedBox(height: SaoSpacing.xs),
      Text('TMQ', style: SaoTypography.projectTitle.copyWith(
        color: SaoColors.onActionPrimary,
      )),
      Text('Tláhuac-Mixcoac-Quiroga', style: SaoTypography.caption.copyWith(
        color: SaoColors.onActionPrimary.withOpacity(0.8),
      )),
    ],
  ),
)
```

---

### 📍 Frente

**Representación Visual:**
- Nombre en **SaoTypography.frontTitle**
- Card con borde izquierdo del color del proyecto
- Ícono de ubicación
- Rango de PK (inicio - fin)

**Ejemplo:**
```dart
Container(
  decoration: BoxDecoration(
    color: SaoColors.surface,
    border: Border(
      left: BorderSide(
        color: ProjectsCatalog.getColor('tmq'),
        width: 4,
      ),
    ),
    borderRadius: BorderRadius.circular(SaoRadii.md),
  ),
  padding: EdgeInsets.all(SaoSpacing.cardPadding),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.location_on, color: SaoColors.gray600),
          SizedBox(width: SaoSpacing.xs),
          Text('Tenerías', style: SaoTypography.frontTitle),
        ],
      ),
      SizedBox(height: SaoSpacing.xs),
      Text('PK 0+000 - 2+500', style: SaoTypography.caption),
    ],
  ),
)
```

---

### 📏 PK (Progresiva)

**Componente Principal**: `SaoPKIndicator`

**Representación Visual:**
- Formato: `0+000.00` (enteros) o `0+000.50` (decimales)
- Tipografía: **SaoTypography.pkLabel**
- Badge con fondo gris claro
- Monospace para alineación

**Ejemplo:**
```dart
Container(
  padding: EdgeInsets.symmetric(
    horizontal: SaoSpacing.sm,
    vertical: SaoSpacing.xs,
  ),
  decoration: BoxDecoration(
    color: SaoColors.gray100,
    borderRadius: BorderRadius.circular(SaoRadii.sm),
    border: Border.all(color: SaoColors.border),
  ),
  child: Text(
    '2+450.50',
    style: SaoTypography.pkLabel.copyWith(
      fontFeatures: [FontFeature.tabularFigures()],  // Monospace
    ),
  ),
)
```

---

### 📋 Actividad

**Componente Principal**: `SaoActivityCard`

**Representación Visual:**
- Barra de color según **riesgo** (izquierda vertical)
- Badge de **estado operativo** (esquina superior derecha)
- Título + PK label
- Metadata: Frente, Municipio
- Footer: ícono + estado

**Anatomía:**
```
┌─┬────────────────────────────────┐
│█│ [BADGE: MEDIO]                 │  ← Badge de riesgo
│█│                                 │
│█│ Caminamiento en Playa Grande   │  ← Título (cardTitle)
│█│ PK: 2+450.50                    │  ← PK (pkLabel)
│█│                                 │
│█│ 📍 Frente Tenerías              │  ← Metadata
│█│ 📌 Tláhuac                      │
│█│                                 │
│█│ ─────────────────────────────  │
│█│ [●] En validación               │  ← Footer con estado
└─┴────────────────────────────────┘
```

---

### ✅ Liberación de Vía

**Componente Principal**: `SaoLiberacionViaCard`

**Representación Visual:**
- Card grande con header verde/rojo según estado
- Rango de PK prominente
- Timestamp de liberación
- Firma digital (nombre del aprobador)
- Contador de actividades/evidencias

**Ejemplo:**
```dart
SaoLiberacionViaCard(
  frente: 'Tenerías',
  pkRange: PKRange(start: 0.0, end: 2.5),
  status: 'liberado',
  timestamp: DateTime.now(),
  approvedBy: 'Ing. García',
  activities: 24,
  evidences: 48,
)

// Render visual:
┌────────────────────────────────────┐
│ 🟢 VÍA LIBERADA                    │  ← Header verde
│────────────────────────────────────│
│ Frente: Tenerías                   │
│ Rango: PK 0+000 - 2+500            │  ← pkLabel grande
│                                    │
│ Liberado: 18 Feb 2026, 14:30       │
│ Por: Ing. García                   │  ← Firma
│                                    │
│ ✓ 24 actividades aprobadas         │
│ 📷 48 evidencias adjuntas          │
└────────────────────────────────────┘
```

---

### 🚨 Evento Crítico

**Representación Visual:**
- Card con borde rojo grueso
- Badge de PRIORITARIO prominente
- Timestamp grande
- Descripción del evento
- Acciones requeridas
- Responsables asignados

**Ejemplo:**
```dart
Container(
  decoration: BoxDecoration(
    color: SaoColors.surface,
    border: Border.all(
      color: SaoColors.riskPriority,
      width: 3,
    ),
    borderRadius: BorderRadius.circular(SaoRadii.md),
  ),
  child: Column(
    children: [
      // Header rojo
      Container(
        color: SaoColors.riskPriorityBg,
        padding: EdgeInsets.all(SaoSpacing.md),
        child: Row(
          children: [
            Icon(Icons.warning, color: SaoColors.riskPriority, size: 32),
            SizedBox(width: SaoSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EVENTO CRÍTICO', style: SaoTypography.label.copyWith(
                  color: SaoColors.riskPriority,
                )),
                Text('18 Feb 2026, 14:30', style: SaoTypography.caption),
              ],
            ),
          ],
        ),
      ),
      // Contenido
      Padding(
        padding: EdgeInsets.all(SaoSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Obstrucción en vía detectada', style: SaoTypography.cardTitle),
            SizedBox(height: SaoSpacing.sm),
            Text('PK 2+450 - Frente Tenerías', style: SaoTypography.body),
            SizedBox(height: SaoSpacing.md),
            Text('Acción requerida:', style: SaoTypography.label),
            Text('Inspección inmediata', style: SaoTypography.body),
          ],
        ),
      ),
    ],
  ),
)
```

---

### 📊 Reporte/Dashboard

**Componente Principal**: `SaoMetricCard` (grid responsivo)

**Layout Desktop:**
```
┌──────────┬──────────┬──────────┬──────────┐
│ Metric 1 │ Metric 2 │ Metric 3 │ Metric 4 │  ← Grid 4 columnas
├──────────┴──────────┴──────────┴──────────┤
│                                            │
│         Gráfico principal                  │  ← Chart grande
│                                            │
├──────────────────┬─────────────────────────┤
│ Lista reciente   │ Mapa geolocalizado      │  ← 2 columnas
│                  │                         │
└──────────────────┴─────────────────────────┘
```

**Métricas típicas SAO:**
- Actividades hoy
- En campo ahora
- Pendientes validación
- Vías liberadas

---

## 📚 Recursos Adicionales

- **SAO_DESIGN_SYSTEM.md**: Documentación completa de componentes y widgets
- **MIGRATION_ACTIVITY_CARD.md**: Guía de migración de `ActivityMiniCard` → `SaoActivityCard`
- **SAO_DOCS_INDEX.md**: Índice general de documentación
- **SAO_UI_FOUNDATION.md**: Fundamentos visuales y principios de diseño
- **SAO_DOMAIN_UI_GUIDELINES.md**: Guía visual de entidades del dominio

---

## 🎯 Siguiente Paso

**Synchronize entre Mobile y Desktop:**

Si agregas un nuevo color o componente en uno de los proyectos, debes:

1. Crear/modificar el archivo en `desktop_flutter/sao_desktop/lib/ui/`
2. Copiar el archivo a `frontend_flutter/sao_windows/lib/ui/`
3. Exportar en `sao_ui.dart` (desktop) si es un widget nuevo
4. Verificar que compile en ambos proyectos

**Comando de copia (ejemplo):**
```powershell
Copy-Item "D:\SAO\desktop_flutter\sao_desktop\lib\ui\theme\sao_colors.dart" `
  -Destination "D:\SAO\frontend_flutter\sao_windows\lib\ui\theme\sao_colors.dart"
```

---

## 📫 Preguntas Frecuentes

**P: ¿Puedo usar `Colors.transparent`?**  
R: Sí, `Colors.transparent` es la excepción permitida.

**P: ¿Qué hago si necesito un color que no existe en SaoColors?**  
R: Agrégalo a `sao_colors.dart` siguiendo la nomenclatura existente y sincroniza entre proyectos.

**P: ¿Los componentes SAO son 100% idénticos en mobile y desktop?**  
R: Sí, especialmente `SaoActivityCard` que fue diseñado para ser idéntico. Algunos componentes tienen hover en desktop pero son visualmente iguales.

**P: ¿Puedo modificar SaoTypography y agregar un nuevo estilo?**  
R: Sí, pero debe seguir la jerarquía existente y sincronizarse entre proyectos.

**P: ¿Dónde están los componentes especializados como SaoProjectSwitcher?**  
R: Están en desarrollo. Este documento define la especificación, la implementación se realizará progresivamente.

**P: ¿Cómo diferencio riesgo de estado operativo?**  
R: **Riesgo** es la criticidad de la actividad (bajo/medio/alto/prioritario). **Estado operativo** es el flujo de trabajo (pendiente/en_campo/en_validacion/aprobado/rechazado). Son independientes.

**P: ¿Hay diseños para mobile o solo desktop?**  
R: Los componentes son **responsivos**. Usan `SaoLayout` para adaptarse automáticamente. El mismo componente funciona en mobile y desktop con layout fluido.

---

## 🎯 Próximos Pasos

### Fase 1: Completar Tokens Base ✅
- [x] SaoColors (base + estados operativos)
- [x] SaoTypography (base + jerarquía operativa)
- [x] SaoSpacing, SaoRadii, SaoShadows (✅ sm/md/lg corregidos)
- [x] SaoLayout (breakpoints + helpers responsivos)
- [x] SaoMotion (duraciones + curvas)

### Fase 2: Componentes Especializados ⚡ EN CURSO
- [x] SaoProjectSwitcher (stub con API estable)
- [x] SaoPKIndicator (stub con API estable)
- [x] SaoSyncIndicator (✅ funcional)
- [x] SaoRoleBadge (✅ funcional)
- [x] SaoMetricCard (✅ funcional con hover)
- [x] SaoTimelineItem (✅ funcional)
- [x] SaoLiberacionViaCard (✅ funcional)
- [x] SaoEvidenceGallery (✅ funcional móvil)
- [ ] **SaoEvidenceViewer** (🔥 PRIORIDAD 1 - Desktop Admin con caption)
- [ ] **SaoActivityTimeline** (🔥 PRIORIDAD 2 - Auditoría completa)
- [ ] **SaoValidationQueue** (Desktop Admin - Cola con filtros)
- [ ] **SaoValidationDetail** (Desktop Admin - Panel de revisión)
- [ ] **SaoCatalogRequestCard** (🔥 PRIORIDAD 4 - Aprobación de catálogos)
- [ ] **SaoReportGenerator** (🔥 PRIORIDAD 3 - Generador de reportes)

### Fase 3: Pantallas Desktop Admin 🖥️ NUEVA
- [ ] **"Validación de Operaciones"** (Pantalla clave con 4 zonas)
  * Zona A: Sidebar (módulos) ✅ Diseño definido
  * Zona B: Cola de validación (lista con filtros fuertes) ⚠️ Requiere SaoValidationQueue
  * Zona C: Detalle técnico (revisión + validaciones) ⚠️ Requiere SaoValidationDetail
  * Zona D: Evidencias con caption ⚠️ **Requiere SaoEvidenceViewer**
- [ ] **Trazabilidad / Auditoría** ⚠️ Requiere SaoActivityTimeline
- [ ] **Reportes** (generación + historial) ⚠️ Requiere SaoReportGenerator
- [ ] **Gestión de Catálogos** (aprobación de solicitudes) ⚠️ Requiere SaoCatalogRequestCard
- [ ] **Usuarios / Roles** (administración de accesos)

### Fase 4: Backend Implementation 🗄️
- [ ] **Evidence** con campo `caption` obligatorio
- [ ] **ActivityAuditLog** con eventos rastreados
- [ ] **Report** versionado e inmutable
- [ ] **CatalogChangeRequest** con workflow de aprobación
- [ ] **CatalogVersion** con distribución incremental
- [ ] API endpoints:
  * `POST /validation/approve` - Aprobar actividad
  * `POST /validation/reject` - Rechazar con motivo
  * `POST /validation/request-correction` - Solicitar corrección
  * `POST /reports/generate` - Generar reporte
  * `GET /audit/:activityId` - Obtener timeline
  * `POST /catalogs/requests/:id/approve` - Aprobar solicitud de catálogo
  * `POST /catalogs/requests/:id/reject` - Rechazar solicitud

### Fase 5: Documentación Avanzada 📚
- [x] SISTEMA_DISEÑO_SAO.md ✅ (1802→2400+ líneas con admin)
- [ ] SAO_ADMIN_DESKTOP_GUIDE.md (guía completa desktop admin)
- [ ] SAO_VALIDATION_WORKFLOW.md (flujo de validación institucional)
- [ ] SAO_REPORT_TEMPLATES.md (plantillas de reportes)
- [ ] SAO_CATALOG_MANAGEMENT.md (gestión de catálogos)
- [ ] SAO_ANIMATION_GUIDE.md (guía de motion design)
- [ ] SAO_RESPONSIVE_GUIDELINES.md (patrones de layout responsivo)

### Fase 6: Testing & Refinamiento 🔬
- [ ] Storybook completo (catálogo interactivo desktop+mobile)
- [ ] Tests visuales de regresión
- [ ] Auditoría de accesibilidad (WCAG 2.1)
- [ ] Performance profiling de animaciones
- [ ] Testing de aprobación/rechazo (workflow completo)
- [ ] Testing de generación de reportes (Word + PDF)
- [ ] Testing de distribución de catálogos (sync incremental)

---

## 📊 Nivel del Sistema

### Estado Actual: 🟢 8/10 - Design System Enterprise (Mobile + Desktop Base)
- ✅ Tokens completos (colores, tipografía, motion, layout)
- ✅ Componentes base implementados
- ✅ 8 widgets especializados (5 funcionales, 3 stubs)
- ✅ Compartido mobile + desktop
- ✅ Estados operativos diferenciados de riesgos
- ✅ Normalización inteligente (acentos, espacios, case-insensitive)
- ⚠️ Falta: Componentes Admin Desktop (evidencias con caption, timeline, reportes)
- ⚠️ Falta: Pantalla completa "Validación de Operaciones"
- ⚠️ Falta: Backend entities (AuditLog, Report, CatalogRequest)

### Objetivo Final: 🟢 10/10 - Enterprise Admin System
- ✅ Tokens operativos
- ✅ Motion system profesional
- ✅ Layout responsivo
- ✅ Componentes especializados del dominio
- ✅ **Componentes Admin Desktop**:
  * SaoEvidenceViewer (con caption obligatorio + metadata GPS)
  * SaoActivityTimeline (trazabilidad completa)
  * SaoValidationQueue (cola con filtros administrativos)
  * SaoValidationDetail (panel de revisión con validaciones automáticas)
  * SaoCatalogRequestCard (workflow de aprobación)
  * SaoReportGenerator (Word + PDF con plantillas)
- ✅ **Pantalla "Validación de Operaciones"** (4 zonas)
- ✅ **Backend completo** (Activity, Evidence, AuditLog, Report, CatalogRequest)
- ✅ **Trazabilidad total** (timeline de eventos)
- ✅ **Reportes institucionales** (versionados, inmutables, con firmas)
- ✅ **Gestión de catálogos** (solicitudes + aprobaciones + distribución)

---

## 🎯 Orden de Implementación Recomendado

### 1. Evidence con Caption (CRÍTICO) 🔥
**Por qué primero**: Sin esto, no puedes validar actividades para reportes institucionales.

**Tareas:**
- [ ] Agregar campo `caption` a modelo `Evidence` (backend)
- [ ] Modificar captura en móvil: caption obligatorio al tomar foto
- [ ] Crear `SaoEvidenceViewer` (desktop) con:
  * Foto grande con zoom/pan
  * Pie de foto completo (caption + metadata)
  * Validaciones visuales (✅/⚠️/❌)
  * Acciones: Abrir mapa, Descargar, Solicitar recaptura
- [ ] Bandera de validación: "Caption faltante" en cola

**Resultado**: Coordinadores pueden validar que evidencias tengan descripción institucional.

---

### 2. Timeline / AuditLog (TRAZABILIDAD) 📋
**Por qué segundo**: Necesitas rastrear todas las acciones para auditoría institucional.

**Tareas:**
- [ ] Crear modelo `ActivityAuditLog` con eventos
- [ ] Hook en backend: cada action → genera `AuditEvent`
- [ ] Crear `SaoActivityTimeline` (desktop) con:
  * Timeline vertical con conectores
  * Icono + color por tipo de evento
  * Actor + rol + timestamp
  * Metadata (antes/después si aplica)
- [ ] Integrar en panel de detalle (Zona C)
- [ ] Vista completa en módulo "Trazabilidad"

**Resultado**: Trazabilidad completa de quién hizo qué y cuándo.

---

### 3. Report Generator (PLANTILLA BÁSICA) 📄
**Por qué tercero**: Coordinadores necesitan exportar reportes oficiales.

**Tareas:**
- [ ] Crear modelo `Report` versionado
- [ ] Implementar plantilla "Reporte Diario" (básica)
- [ ] Crear `SaoReportGenerator` (desktop) con:
  * Selector de plantilla
  * Filtros (proyecto, frente, fechas)
  * Vista previa (opcional)
  * Generación: Word (.docx) + PDF
- [ ] Guardar versión inmutable (hash SHA-256)
- [ ] Historial de reportes generados

**Resultado**: Coordinadores exportan reportes oficiales con firmas institucionales.

---

### 4. CatalogRequest Approval (WORKFLOW) 🏷️
**Por qué cuarto**: Permite evolución controlada de catálogos desde campo.

**Tareas:**
- [ ] Crear modelo `CatalogChangeRequest`
- [ ] En móvil: botón "Solicitar nuevo tipo/clasificación"
- [ ] Crear `SaoCatalogRequestCard` (desktop) con:
  * Ver propuesta
  * Comparación "Antes vs Después" (si update)
  * Aprobar / Rechazar con motivo
- [ ] Al aprobar: versionar catálogo, marcar para distribución
- [ ] Sync automático: móviles descargan catálogo actualizado

**Resultado**: Catálogos evolucionan de forma controlada sin hardcode.

---

### 5. Pantalla "Validación de Operaciones" Completa 🖥️
**Por qué quinto**: Integra todo lo anterior en una interfaz coherente.

**Tareas:**
- [ ] Crear layout de 4 zonas (responsive)
- [ ] Zona A: Sidebar con módulos + badges
- [ ] Zona B: `SaoValidationQueue` (cola con filtros)
- [ ] Zona C: `SaoValidationDetail` (panel de revisión)
- [ ] Zona D: `SaoEvidenceViewer` (evidencias con caption)
- [ ] Sincronizar selección: al hacer clic en cola → carga detalle + evidencias
- [ ] Testing de workflow completo:
  * Filtrar actividades
  * Seleccionar una
  * Revisar detalle
  * Ver evidencias
  * Aprobar/Rechazar/Solicitar corrección

**Resultado**: Coordinadores tienen "centro de comando" para validación institucional.

---

**🎨 Sistema de Diseño SAO - Versión 2.1 - Febrero 2026**

*Sistema de Diseño Enterprise para Operaciones Ferroviarias*

**Nuevas especificaciones v2.1:**
- ✅ Componentes Admin Desktop (EvidenceViewer, ActivityTimeline, ValidationQueue, ValidationDetail, CatalogRequestCard, ReportGenerator)
- ✅ Pantalla "Validación de Operaciones" (4 zonas: Sidebar, Cola, Detalle, Evidencias)
- ✅ Arquitectura de datos (Activity, Evidence con caption, AuditLog, Report, CatalogRequest, CatalogVersion)
- ✅ Workflow de validación institucional (Aprobar, Rechazar, Solicitar corrección)
- ✅ Trazabilidad completa (Timeline de eventos con actor, rol, timestamp)
- ✅ Reportes versionados e inmutables (Word + PDF con firmas institucionales)
- ✅ Gestión de catálogos (Solicitudes + Aprobaciones + Distribución incremental)

**ADN SAO:**
- **Mobile (Operativo)**: Captura en campo con evidencias geolocalizadas
- **Desktop (Coordinador/Admin)**: Validación institucional + Trazabilidad + Reportes + Gestión de catálogos
- **Regla de oro**: **SaoActivityCard debe verse IGUAL en mobile y desktop** (ADN visual compartido)
