// lib/ui/sao_ui.dart
/// Sistema de Diseño Completo del SAO (Design System + Catálogos Globales)
/// 
/// Este archivo exporta todo el ecosistema UI centralizado compartido entre
/// SAO Mobile y SAO Desktop para garantizar consistencia visual y de datos.
/// 
/// Uso:
/// ```dart
/// import 'package:sao_windows/ui/sao_ui.dart';
/// 
/// // Theme
/// MaterialApp(theme: SaoTheme.lightTheme)
/// 
/// // Colors & Typography
/// Container(color: SaoColors.actionPrimary)
/// Text('Título', style: SaoTypography.titleMedium)
/// 
/// // Widgets
/// SaoCard(child: ...)
/// SaoButton.primary(text: 'Guardar', onPressed: () {})
/// SaoField(label: 'Nombre', ...)
/// SaoDropdown(items: [...], ...)
/// SaoPanel(title: 'Sección', child: ...)
/// 
/// // Catálogos (fuentes únicas de verdad)
/// // Actividades: CatalogRepository.activities (bundle-driven)
/// StatusCatalog.aprobado
/// RiskCatalog.prioritario  // ← Homologado mobile ↔ desktop
/// RolesCatalog.coordinador
/// ProjectsCatalog.tmq
/// 
/// // Helpers
/// SaoFormat.date(DateTime.now())
/// SaoValidators.requiredEmail(email)
/// SaoPlatform.isMobile
/// ```
library;


// ============================================================
// THEME: Colores, Tipografía, Espaciado, Radios, Sombras, Motion, Layout
// ============================================================
export 'theme/sao_colors.dart';
export 'theme/sao_typography.dart';
export 'theme/sao_spacing.dart';
export 'theme/sao_radii.dart';
export 'theme/sao_shadows.dart';
export 'theme/sao_motion.dart';
export 'theme/sao_layout.dart';
export 'theme/sao_theme.dart';

// ============================================================
// WIDGETS: Componentes reutilizables
// ============================================================
export 'widgets/sao_card.dart';
export 'widgets/sao_button.dart';
export 'widgets/sao_chip.dart';
export 'widgets/sao_badge.dart';
export 'widgets/sao_input.dart';
export 'widgets/sao_alert_card.dart';
export 'widgets/sao_empty_state.dart';
export 'widgets/sao_dropdown.dart';
export 'widgets/sao_field.dart';
export 'widgets/sao_panel.dart';
export 'widgets/sao_activity_card.dart';

// ============================================================
// WIDGETS ESPECIALIZADOS SAO: Componentes del dominio ferroviario
// ============================================================
export 'widgets/special/sao_project_switcher.dart';
export 'widgets/special/sao_pk_indicator.dart';
export 'widgets/special/sao_sync_indicator.dart';
export 'widgets/special/sao_role_badge.dart';
export 'widgets/special/sao_metric_card.dart';
export 'widgets/special/sao_timeline_item.dart';
export 'widgets/special/sao_liberacion_via_card.dart';
export 'widgets/special/sao_evidence_gallery.dart';

// ============================================================
// HELPERS: Formato, Validación, Detección de Plataforma
// ============================================================
export 'helpers/sao_format.dart';
export 'helpers/sao_validators.dart';
export 'helpers/sao_platform.dart';

// ============================================================
// CATÁLOGOS GLOBALES: Fuentes únicas de verdad
// ============================================================
export '../catalog/status_catalog.dart';
export '../catalog/risk_catalog.dart';
export '../catalog/roles_catalog.dart';
export '../catalog/projects_catalog.dart';