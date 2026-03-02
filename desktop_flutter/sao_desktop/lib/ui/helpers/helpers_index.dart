// lib/ui/helpers/helpers_index.dart
/// Índice central de helpers UI del SAO
/// Importa este archivo para acceder a todos los helpers:
/// 
/// ```dart
/// import 'package:sao_desktop/ui/helpers/helpers_index.dart';
/// 
/// // Uso:
/// final formatted = SaoFormat.date(DateTime.now());
/// final isValid = SaoValidators.email('test@example.com');
/// final isDesktop = SaoPlatform.isDesktop;
/// ```

export 'sao_format.dart';
export 'sao_validators.dart';
export 'sao_platform.dart';
