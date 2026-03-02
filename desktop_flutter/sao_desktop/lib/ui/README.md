# Sistema de Diseño SAO 🎨

**Design System + Catálogos Globales compartidos entre SAO Mobile y SAO Desktop**

## 📖 Índice

- [Introducción](#introducción)
- [Estructura](#estructura)
- [Instalación](#instalación)
- [Uso Básico](#uso-básico)
- [Theme](#theme)
- [Widgets](#widgets)
- [Catálogos](#catálogos)
- [Helpers](#helpers)
- [Reglas de Oro](#reglas-de-oro)

## 🌟 Introducción

Este sistema de diseño garantiza **consistencia visual y de datos** entre la aplicación móvil y el programa de escritorio del SAO.

### ¿Por qué existe?

1. **Evitar inconsistencias**: Un solo lugar define colores, estilos, estados, etc.
2. **Homologación Mobile ↔ Desktop**: Mismo look, mismos datos, misma lógica
3. **Productividad**: Widgets listos para usar, no reinventar la rueda
4. **Mantenibilidad**: Cambiar un color → se actualiza en todo el ecosistema

## 📁 Estructura

```
lib/
├── ui/
│   ├── sao_ui.dart              # ⭐ Import único para todo
│   ├── theme/
│   │   ├── sao_colors.dart      # Paleta de colores
│   │   ├── sao_typography.dart  # Estilos de texto
│   │   ├── sao_spacing.dart     # Espaciados
│   │   ├── sao_radii.dart       # Bordes redondeados
│   │   ├── sao_shadows.dart     # Sombras
│   │   └── sao_theme.dart       # ThemeData completo
│   ├── widgets/
│   │   ├── sao_card.dart
│   │   ├── sao_button.dart
│   │   ├── sao_field.dart
│   │   ├── sao_dropdown.dart
│   │   ├── sao_panel.dart
│   │   └── ...
│   └── helpers/
│       ├── sao_format.dart      # Formateo de datos
│       ├── sao_validators.dart  # Validaciones
│       └── sao_platform.dart    # Detección de plataforma
├── catalog/
│   ├── activity_catalog.dart    # Tipos de actividad
│   ├── status_catalog.dart      # Estados del flujo
│   ├── risk_catalog.dart        # Niveles de riesgo
│   ├── roles_catalog.dart       # Roles y permisos
│   └── projects_catalog.dart    # Proyectos
```

## 🚀 Instalación

### 1. Importar el sistema

En cualquier archivo donde necesites UI o catálogos:

```dart
import 'package:sao_desktop/ui/sao_ui.dart';
```

**Eso es todo.** Ya tienes acceso a todo el sistema.

### 2. Configurar el theme en `main.dart`

```dart
void main() {
  runApp(
    MaterialApp(
      theme: SaoTheme.lightTheme,  // ← Theme centralizado
      home: const HomeView(),
    ),
  );
}
```

## 🎨 Uso Básico

### Theme & Colors

```dart
// ✅ Correcto: usar tokens
Container(
  color: SaoColors.actionPrimary,
  padding: EdgeInsets.all(SaoSpacing.lg),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(SaoRadii.lg),
    boxShadow: [SaoShadows.medium],
  ),
)

// ❌ Incorrecto: hardcodear valores
Container(
  color: Color(0xFF1A2B45),  // NO
  padding: EdgeInsets.all(16),  // NO
)
```

### Typography

```dart
// ✅ Correcto
Text('Título', style: SaoTypography.titleMedium)
Text('Cuerpo', style: SaoTypography.bodyText)
Text('Caption', style: SaoTypography.caption())

// ❌ Incorrecto
Text('Título', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))  // NO
```

## 🧩 Widgets

### SaoButton

```dart
// Botón primario
SaoButton.primary(
  text: 'Guardar',
  onPressed: () {},
  icon: Icons.save,
)

// Botón secundario
SaoButton.secondary(
  text: 'Cancelar',
  onPressed: () {},
)

// Botón peligroso
SaoButton.danger(
  text: 'Eliminar',
  onPressed: () {},
)
```

### SaoField

```dart
SaoField(
  label: 'Nombre',
  hint: 'Ingresa tu nombre',
  icon: Icons.person,
  validator: SaoValidators.required,
  isEdited: true,  // Muestra indicador "Editado"
)
```

### SaoDropdown

```dart
SaoDropdown<String>(
  label: 'Actividad',
  value: selectedActivity,
  items: ActivityCatalog.dropdownItems(),
  onChanged: (value) => setState(() => selectedActivity = value),
  icon: Icons.event,
)
```

### SaoPanel

```dart
SaoPanel(
  title: 'Información General',
  subtitle: 'Datos básicos del registro',
  trailing: TextButton(
    child: Text('Editar'),
    onPressed: () {},
  ),
  child: Column(
    children: [
      // Contenido del panel
    ],
  ),
)
```

### SaoCard

```dart
SaoCard(
  child: Padding(
    padding: EdgeInsets.all(SaoSpacing.lg),
    child: Text('Contenido de la tarjeta'),
  ),
)
```

## 📚 Catálogos

### Activity Catalog

```dart
// Obtener actividad
final activity = ActivityCatalog.caminamiento;
print(activity.label);  // "Caminamiento"
print(activity.icon);   // Icons.directions_walk
print(activity.defaultRisk);  // "medio"

// Buscar por ID
final activity = ActivityCatalog.findById('CAM');

// Dropdown
ActivityCatalog.dropdownItems()

// Todas las actividades
ActivityCatalog.all
```

### Status Catalog

```dart
// Estados disponibles
StatusCatalog.nuevo
StatusCatalog.enRevision
StatusCatalog.aprobado
StatusCatalog.rechazado
StatusCatalog.sincronizado

// Badge visual
StatusCatalog.badge('aprobado')  // Widget listo
```

### Risk Catalog

```dart
// Niveles de riesgo (📱 homologados con mobile)
RiskCatalog.bajo
RiskCatalog.medio
RiskCatalog.alto
RiskCatalog.prioritario  // ← NO "crítico"

// Badge con círculo coloreado (como mobile)
RiskCatalog.badge('prioritario')

// Obtener color
final color = RiskCatalog.getColor('alto');  // Color naranja
```

### Roles Catalog

```dart
// Roles disponibles
RolesCatalog.operativo
RolesCatalog.coordinador
RolesCatalog.admin
RolesCatalog.auditor

// Verificar permisos
if (RolesCatalog.hasPermission(userRole, RolesCatalog.permApproveActivity)) {
  // Usuario puede aprobar
}
```

### Projects Catalog

```dart
// Proyectos
ProjectsCatalog.tmq   // Tren Maya Quintana Roo
ProjectsCatalog.tap   // Tren Aeropuerto Pachuca
ProjectsCatalog.snl   // Sistema Nacional Logística

// Chip visual
ProjectsCatalog.chip('TMQ')
```

## 🛠️ Helpers

### SaoFormat

```dart
// Fechas
SaoFormat.date(DateTime.now())  // "18/02/2026"
SaoFormat.time(DateTime.now())  // "14:30"
SaoFormat.dateRelative(date)    // "Hace 3 días"

// Números
SaoFormat.number(1234)          // "1,234"
SaoFormat.currency(1234.56)     // "$1,234.56"
SaoFormat.percent(0.45)         // "45%"

// PKs y códigos
SaoFormat.pk('OP', 1234)        // "OP-2026-001234"
SaoFormat.shortId(123)          // "000123"

// Texto
SaoFormat.truncate('Texto largo...', 20)
SaoFormat.initials('Juan Pérez')  // "JP"

// Archivos
SaoFormat.fileSize(1048576)     // "1.0 MB"
```

### SaoValidators

```dart
SaoField(
  validator: SaoValidators.combine([
    SaoValidators.required,
    SaoValidators.minLength(value, 3),
    SaoValidators.email,
  ]),
)

// Validadores disponibles
SaoValidators.required(value)
SaoValidators.email(value)
SaoValidators.phoneNumberMX(value)
SaoValidators.number(value)
SaoValidators.min(value, 0)
SaoValidators.maxLength(value, 100)
```

### SaoPlatform

```dart
// Detección
if (SaoPlatform.isDesktop) {
  // Lógica específica de desktop
}

if (SaoPlatform.isMobile) {
  // Lógica específica de mobile
}

// Adaptación de UI
final padding = SaoPlatform.pagePadding;  // 16 desktop, 20 mobile
final density = SaoPlatform.visualDensity;  // -1 desktop, 0 mobile

// Capacidades
if (SaoPlatform.supportsKeyboardShortcuts) {
  // Registrar shortcuts
}
```

## ⚠️ Reglas de Oro

### 1. **NUNCA hardcodear colores**

```dart
// ❌ MAL
Container(color: Color(0xFF1A2B45))
Container(color: Colors.blue)

// ✅ BIEN
Container(color: SaoColors.actionPrimary)
```

### 2. **NUNCA hardcodear strings de catálogo**

```dart
// ❌ MAL
if (status == 'aprobado') { ... }
dropdown(items: ['Caminamiento', 'Reunión', ...])

// ✅ BIEN
if (status == StatusCatalog.aprobado.id) { ... }
dropdown(items: ActivityCatalog.dropdownItems())
```

### 3. **NUNCA hardcodear estilos de texto**

```dart
// ❌ MAL
Text('Hola', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))

// ✅ BIEN
Text('Hola', style: SaoTypography.titleMedium)
```

### 4. **Usar widgets SAO en lugar de Material básicos**

```dart
// ❌ Evitar
TextField(...)
ElevatedButton(...)
Card(...)

// ✅ Preferir
SaoField(...)
SaoButton.primary(...)
SaoCard(...)
```

### 5. **Importar solo sao_ui.dart**

```dart
// ❌ NO hacer múltiples imports
import 'package:sao_desktop/ui/theme/sao_colors.dart';
import 'package:sao_desktop/ui/widgets/sao_button.dart';
import 'package:sao_desktop/catalog/activity_catalog.dart';

// ✅ Un solo import
import 'package:sao_desktop/ui/sao_ui.dart';
```

## 🔄 Sincronización Mobile ↔ Desktop

Este sistema es **idéntico** en ambas apps. Cualquier cambio en:

- Colores
- Tipografía
- Widgets
- Catálogos

Se refleja automáticamente en Mobile y Desktop si ambos usan la misma versión del sistema de diseño.

### Diferencias adaptativas

El sistema detecta automáticamente la plataforma y ajusta:

- **Densidad visual**: Desktop más compacto
- **Tamaños de fuente**: Desktop ligeramente más pequeños
- **Espaciados**: Desktop más ajustados
- **Tooltips**: Solo en desktop
- **Shortcuts**: Solo en desktop

Pero los **colores, nomenclatura, y catálogos son idénticos**.

## 🚨 Mantenimiento

### Para agregar un nuevo color:

1. Editar `lib/ui/theme/sao_colors.dart`
2. Agregar constante `static const nuevoColor = Color(0x...)`
3. Usar en el código: `SaoColors.nuevoColor`

### Para agregar una nueva actividad:

1. Editar `lib/catalog/activity_catalog.dart`
2. Agregar constante en el catálogo
3. Agregar a lista `all`
4. Usar: `ActivityCatalog.nuevaActividad`

### Para agregar un nuevo widget:

1. Crear `lib/ui/widgets/sao_nuevo_widget.dart`
2. Exportar en `lib/ui/widgets/widgets_index.dart`
3. Exportar en `lib/ui/sao_ui.dart`
4. Usar: `import 'package:sao_desktop/ui/sao_ui.dart'`

---

**Última actualización**: Febrero 2026  
**Mantenedor**: Equipo SAO
