# SAO — Design Tokens
**Versión:** 1.0.0 | **Fecha:** 2026-03-04

---

## 0. Regla Fundamental

> **Ningún archivo en `features/` puede usar `Color(0xFF...)`, `Colors.red`, `Colors.green`, ni ningún valor de color directo.**
>
> **Todo color debe venir de `SaoColors.*` o de un token semántico del catálogo.**
>
> **En Desktop, los neutros de layout deben salir de helpers theme-aware (`SaoColors.scaffoldBackgroundFor`, `surfaceFor`, `surfaceMutedFor`, `surfaceRaisedFor`, `borderFor`, `textFor`, `textMutedFor`) y no de `surface`, `gray50` o `gray100` directos cuando el widget deba responder a dark mode.**

Violaciones detectadas: ver [AUDIT_REPORT.md §1.2](AUDIT_REPORT.md).

---

## 1. Tokens Semánticos (SaoColors)

**Ubicación:** `lib/ui/theme/sao_colors.dart` (mobile) · `lib/ui/theme/sao_colors.dart` (desktop)

### 1.1 Colores base (primitivos — solo para uso interno en SaoColors)

```dart
// PRIMITIVOS: no usar directamente en features/
static const Color _gray50  = Color(0xFFF9FAFB);
static const Color _gray100 = Color(0xFFF3F4F6);
static const Color _gray200 = Color(0xFFE5E7EB);
static const Color _gray400 = Color(0xFF9CA3AF);
static const Color _gray600 = Color(0xFF6B7280);
static const Color _gray800 = Color(0xFF1F2937);
static const Color _gray900 = Color(0xFF111827);
static const Color _blue400 = Color(0xFF60A5FA);
static const Color _blue500 = Color(0xFF3B82F6);
static const Color _green600 = Color(0xFF16A34A);
static const Color _amber500 = Color(0xFFF59E0B);
static const Color _orange500 = Color(0xFFF97316);
static const Color _red600  = Color(0xFFDC2626);
static const Color _purple500 = Color(0xFF8B5CF6);
static const Color _indigo500 = Color(0xFF6366F1);
```

### 1.2 Tokens semánticos (usar SIEMPRE estos en features/)

```dart
// Texto
static const Color textPrimary   = _gray900;
static const Color textSecondary = _gray600;
static const Color textDisabled  = _gray400;
static const Color textOnDark    = Colors.white;

// Superficie y borde
static const Color surface       = Colors.white;
static const Color surfaceAlt    = _gray50;
static const Color border        = _gray200;
static const Color borderStrong  = _gray400;

// Desktop dark-mode aware helpers
static Color scaffoldBackgroundFor(BuildContext context) { /* dark/light */ }
static Color surfaceFor(BuildContext context) { /* dark/light */ }
static Color surfaceMutedFor(BuildContext context) { /* dark/light */ }
static Color surfaceRaisedFor(BuildContext context) { /* dark/light */ }
static Color borderFor(BuildContext context) { /* dark/light */ }
static Color textFor(BuildContext context) { /* dark/light */ }
static Color textMutedFor(BuildContext context) { /* dark/light */ }

// Feedback (semánticos)
static const Color success       = _green600;
static const Color warning       = _amber500;
static const Color error         = _red600;
static const Color info          = _blue500;
static const Color infoBg        = Color(0xFFEFF6FF);  // blue-50

// Riesgo (mapear desde strings del catálogo)
static const Color riskLow       = _green600;
static const Color riskMedium    = _amber500;
static const Color riskHigh      = _orange500;
static const Color riskCritical  = _red600;

// Backgrounds de riesgo (14% opacidad)
static Color riskLowBg      = _green600.withOpacity(0.14);
static Color riskMediumBg   = _amber500.withOpacity(0.14);
static Color riskHighBg     = _orange500.withOpacity(0.14);
static Color riskCriticalBg = _red600.withOpacity(0.14);

// Estado workflow
static const Color statusBorrador         = _gray400;
static const Color statusNuevo            = _blue400;
static const Color statusEnRevision       = _amber500;
static const Color statusRequiereCambios  = _orange500;
static const Color statusAprobado         = _green600;
static const Color statusRechazado        = _red600;
static const Color statusSincronizado     = _indigo500;
static const Color statusOffline          = _gray600;
static const Color statusConflicto        = _orange500;

// Actividades (derivar del catálogo — tokens por ID de actividad)
static const Color activityCam = _green600;
static const Color activityReu = _blue500;
static const Color activityAsp = _purple500;
static const Color activityCin = _amber500;
static const Color activitySoc = _red600;
static const Color activityAin = _gray600;
```

### 1.3 Helpers (usar en lugar de if/switch en features/)

```dart
// Riesgo
static Color getRiskColor(String level) {
  switch (level.toLowerCase()) {
    case 'bajo': case 'low':       return riskLow;
    case 'medio': case 'medium':   return riskMedium;
    case 'alto': case 'high':      return riskHigh;
    case 'prioritario': case 'critical': case 'critico': return riskCritical;
    default: return _gray400;
  }
}

static Color getRiskBackground(String level) { /* mismo pattern con Bg */ }

// Estado
static Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'borrador': case 'draft':         return statusBorrador;
    case 'nuevo': case 'en_curso':         return statusNuevo;
    case 'en_revision': case 'revision_pendiente': return statusEnRevision;
    case 'requiere_cambios':               return statusRequiereCambios;
    case 'aprobado': case 'completada':    return statusAprobado;
    case 'rechazado':                      return statusRechazado;
    case 'sincronizado': case 'synced':    return statusSincronizado;
    case 'offline':                        return statusOffline;
    case 'conflicto': case 'conflict':     return statusConflicto;
    default: return _gray400;
  }
}

// Actividad (por ID del catálogo)
static Color getActivityColor(String activityId) {
  // Primero intentar desde CatalogBundle.colorTokens
  // Fallback a mapa local:
  const map = {
    'CAM': activityCam,
    'REU': activityReu,
    'ASP': activityAsp,
    'CIN': activityCin,
    'SOC': activitySoc,
    'AIN': activityAin,
  };
  return map[activityId.toUpperCase()] ?? _gray400;
}
```

---

## 2. Tokens del Catálogo (Dinámicos)

El bundle de catálogo incluye `effective.color_tokens` que mapea tokens semánticos a valores hex. Los clientes deben:

1. Cargar bundle al iniciar.
2. Extraer `color_tokens` y sobreescribir los defaults locales.
3. Usar `CatalogRepository.colorToken(tokenKey)` para obtener colores.

```dart
// Ejemplo en widget:
final color = ref.read(catalogRepositoryProvider)
    .colorToken('activity.cam')        // desde catálogo
    ?? SaoColors.activityCam;          // fallback local
```

**Token keys estándar:**

| Token Key | Default | Uso |
|-----------|---------|-----|
| `activity.cam` | `#16A34A` | Caminamiento |
| `activity.reu` | `#3B82F6` | Reunión |
| `activity.asp` | `#8B5CF6` | Asamblea |
| `activity.cin` | `#F59E0B` | Consulta Indígena |
| `activity.soc` | `#EF4444` | Socialización |
| `activity.ain` | `#6B7280` | Acompañamiento Institucional |
| `risk.low` | `#16A34A` | Riesgo bajo |
| `risk.medium` | `#F59E0B` | Riesgo medio |
| `risk.high` | `#F97316` | Riesgo alto |
| `risk.critical` | `#DC2626` | Riesgo crítico |
| `status.borrador` | `#9CA3AF` | Estado borrador |
| `status.nuevo` | `#60A5FA` | Estado nuevo |
| `status.en_revision` | `#F59E0B` | En revisión |
| `status.requiere_cambios` | `#F97316` | Requiere cambios |
| `status.aprobado` | `#16A34A` | Aprobado |
| `status.rechazado` | `#DC2626` | Rechazado |
| `status.sincronizado` | `#6366F1` | Sincronizado |

---

## 3. Tipografía

**Todos los estilos de texto deben venir del ThemeData o de constantes en SaoTextStyles:**

```dart
// ✅ CORRECTO
Text('Título', style: Theme.of(context).textTheme.titleMedium)
Text('Label', style: SaoTextStyles.label)

// ❌ PROHIBIDO
Text('Título', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)))
```

---

## 4. Spacing y Bordes

Usar constantes en lugar de valores mágicos:

```dart
class SaoSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 24.0;
  static const double xxl = 32.0;
}

class SaoBorder {
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double width    = 1.0;
  static const double widthMd  = 1.5;
}
```

---

## 5. Prohibiciones Explícitas

Los siguientes patrones están **prohibidos** en cualquier archivo dentro de `features/`:

```dart
// ❌ Valores hex directos
Color(0xFF6B7280)
Color(0xFFF3F4F6)

// ❌ Colores de Flutter sin namespace
Colors.red
Colors.green
Colors.amber

// ❌ Variantes de shade sin token
Colors.red.shade600
Colors.blue.shade50

// ❌ withOpacity en features (usar tokens bg)
SomeColor.withOpacity(0.14)  // Usar riskLowBg etc.

// ❌ Tamaños de texto directos
TextStyle(fontSize: 14)      // Usar Theme.of(context).textTheme.*

// ❌ Padding hardcoded como double literal sin constante
Padding(padding: EdgeInsets.all(16.0))  // Usar SaoSpacing.lg
```

---

## 6. Plan de Remediación de Hardcodes

Ver [AUDIT_REPORT.md §1.2](AUDIT_REPORT.md) para lista completa.

**Archivos a corregir (prioridad):**

| Archivo | Instancias | Esfuerzo |
|---------|-----------|---------|
| `features/agenda/widgets/filter_chips_row.dart` | 5+ | 30 min |
| `features/agenda/widgets/agenda_mini_card.dart` | 4 | 20 min |
| `features/home/home_page.dart` | 1 | 5 min |
| `features/settings/settings_page.dart` | 1 | 5 min |
| `features/projects/projects_page.dart` | 5 | 25 min |
| `core/navigation/shell.dart` | 1 | 5 min |
| `desktop/features/admin/admin_shell.dart` | 1 | 5 min |
| `desktop/features/auth/app_login_page.dart` | 3 | 10 min |
| `desktop/features/users/users_page.dart` | 1 | 5 min |

**Total estimado:** ~2 horas para remediar todos los hardcodes de color conocidos.
