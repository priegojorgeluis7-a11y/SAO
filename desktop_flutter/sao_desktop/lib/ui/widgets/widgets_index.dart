// lib/ui/widgets/widgets_index.dart
/// Índice central de widgets del SAO
/// Importa este archivo para acceder a todos los widgets reutilizables:
/// 
/// ```dart
/// import 'package:sao_desktop/ui/widgets/widgets_index.dart';
/// 
/// // Uso:
/// SaoCard(child: ...)
/// SaoButton.primary(text: 'Guardar', onPressed: () {})
/// SaoField(label: 'Nombre', ...)
/// SaoDropdown(items: [...], ...)
/// SaoPanel(title: 'Sección', child: ...)
/// SaoActivityCard(title: 'Actividad', ...)
/// SaoAppShell(title: 'App', body: ...)
/// ```

// Contenedores y estructura
export 'sao_app_shell.dart';
export 'sao_panel.dart';
export 'sao_card.dart';

// Componentes de actividad
export 'sao_activity_card.dart';

// Botones y acciones
export 'sao_button.dart';

// Inputs y formularios
export 'sao_input.dart';
export 'sao_field.dart';
export 'sao_dropdown.dart';

// Badges y chips
export 'sao_badge.dart';
export 'sao_chip.dart';

// Estados y feedback
export 'sao_empty_state.dart';
export 'sao_alert_card.dart';
