class WizardResult {
  final String activityId;

  // Ejemplos mínimos (ajusta a tu UX):
  final String risk; // "Bajo/Medio/Alto/Prioritario"
  final String activityTypeId;
  final String? subcategoryId;
  final String? subcategoryOtherText;
  final String? purposeId;

  final List<String> topicIds;
  final String? topicOtherText;

  final List<String> attendeeIds;

  final String resultId; // R01, R07, etc.
  final List<String> evidencePaths;
  final bool evidenceSent; // por ahora false

  const WizardResult({
    required this.activityId,
    required this.risk,
    required this.activityTypeId,
    required this.resultId,
    this.subcategoryId,
    this.subcategoryOtherText,
    this.purposeId,
    this.topicOtherText,
    this.topicIds = const [],
    this.attendeeIds = const [],
    this.evidencePaths = const [],
    this.evidenceSent = false,
  });
}
