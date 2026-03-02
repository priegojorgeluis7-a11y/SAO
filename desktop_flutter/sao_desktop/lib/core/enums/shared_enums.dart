// Enums y constantes compartidas entre app móvil y escritorio
enum RiskLevel { 
  bajo, 
  medio, 
  alto, 
  prioritario  // 🎯 Homologado con app móvil
}

extension RiskLevelExtension on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.bajo:
        return 'BAJO';
      case RiskLevel.medio:
        return 'MEDIO';
      case RiskLevel.alto:
        return 'ALTO';
      case RiskLevel.prioritario:
        return 'PRIORITARIO';
    }
  }

  String get code {
    switch (this) {
      case RiskLevel.bajo:
        return 'low';
      case RiskLevel.medio:
        return 'medium';
      case RiskLevel.alto:
        return 'high';
      case RiskLevel.prioritario:
        return 'prioritario';
    }
  }

  static RiskLevel fromString(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
      case 'bajo':
        return RiskLevel.bajo;
      case 'medium':
      case 'medio':
        return RiskLevel.medio;
      case 'high':
      case 'alto':
        return RiskLevel.alto;
      case 'critical':
      case 'prioritario':
      case 'critico':
      case 'crítico':
        return RiskLevel.prioritario;
      default:
        return RiskLevel.medio;
    }
  }
}