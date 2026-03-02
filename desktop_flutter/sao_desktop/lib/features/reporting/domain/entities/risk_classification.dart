/// Clasificación de riesgo
class RiskClassification {
  final String riskLevel; // bajo, medio, alto, crítico
  final List<String> tags; // infraestructura_crítica, social, jurídico, etc.
  final String? justification; // justificación manual
  final bool autoDetected; // si fue detectado automáticamente

  RiskClassification({
    required this.riskLevel,
    required this.tags,
    this.justification,
    required this.autoDetected,
  });

  // Colores institucionales por nivel de riesgo
  String get colorHex {
    switch (riskLevel) {
      case 'bajo':
        return '#16A34A'; // verde
      case 'medio':
        return '#F59E0B'; // ámbar
      case 'alto':
        return '#F97316'; // naranja
      case 'crítico':
        return '#DC2626'; // rojo
      default:
        return '#6B7280'; // gris
    }
  }

  String get displayLabel {
    switch (riskLevel) {
      case 'bajo':
        return 'Riesgo Bajo';
      case 'medio':
        return 'Riesgo Medio';
      case 'alto':
        return 'Riesgo Alto';
      case 'crítico':
        return 'Riesgo Crítico';
      default:
        return riskLevel;
    }
  }

  factory RiskClassification.fromText(String text) {
    // Reglas simples de clasificación automática
    final lowerText = text.toLowerCase();
    
    RiskClassification _classify(String level, List<String> detectedTags) {
      return RiskClassification(
        riskLevel: level,
        tags: detectedTags,
        autoDetected: true,
      );
    }

    // Infraestructura crítica (ORO)
    if (lowerText.contains('gasoducto') || lowerText.contains('cenagas')) {
      return _classify('crítico', ['infraestructura_crítica', 'gasoducto']);
    }
    if (lowerText.contains('cfe') || lowerText.contains('electricidad')) {
      return _classify('crítico', ['infraestructura_crítica', 'electricidad']);
    }

    // Social (riesgo medio-alto)
    if (lowerText.contains('ejido') || 
        lowerText.contains('comunidad') || 
        lowerText.contains('asamblea')) {
      return _classify('alto', ['social', 'comunitario']);
    }

    // Jurídico (riesgo medio-alto)
    if (lowerText.contains('avalúo') || 
        lowerText.contains('indaabin') || 
        lowerText.contains('predios')) {
      return _classify('alto', ['jurídico', 'inmueble']);
    }

    // Default: bajo
    return RiskClassification(
      riskLevel: 'bajo',
      tags: [],
      autoDetected: true,
    );
  }
}
