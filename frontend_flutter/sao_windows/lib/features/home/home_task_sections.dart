import 'models/today_activity.dart';
import 'models/task_section_metrics.dart';

class HomeTaskSectionData {
  final String id;
  final List<TodayActivity> items;
  final Map<String, List<TodayActivity>> groupedByFrente;
  final TaskSectionMetrics metrics;

  const HomeTaskSectionData({
    required this.id,
    required this.items,
    required this.groupedByFrente,
    required this.metrics,
  });

  int get itemCount => items.length;

  /// Whether this section should be auto-expanded (critical priority)
  bool get shouldAutoExpand => metrics.priority == SectionPriority.critical;
}

const List<String> _orderedSectionIds = <String>[
  // TIER 1: Action required (critical)
  'por_corregir',
  'error_sync',
  'por_completar',
  // TIER 2: Active work
  'por_iniciar',
  'en_curso',
  'pendiente_sync',
  // TIER 3: Awaiting / other
  'en_revision',
  'otras',
];

String homeTaskSectionIdForNextAction(String nextAction) {
  switch (nextAction.trim().toUpperCase()) {
    case 'INICIAR_ACTIVIDAD':
      return 'por_iniciar';
    case 'TERMINAR_ACTIVIDAD':
      return 'en_curso';
    case 'COMPLETAR_WIZARD':
      return 'por_completar';
    case 'CORREGIR_Y_REENVIAR':
    case 'CERRADA_RECHAZADA':
      return 'por_corregir';
    case 'REVISAR_ERROR_SYNC':
      return 'error_sync';
    case 'SINCRONIZAR_PENDIENTE':
      return 'pendiente_sync';
    case 'ESPERAR_DECISION_COORDINACION':
      return 'en_revision';
    default:
      return 'otras';
  }
}

String homeTaskSectionTitle(String sectionId) {
  switch (sectionId) {
    case 'por_iniciar':
      return 'Por iniciar';
    case 'en_curso':
      return 'En curso';
    case 'por_completar':
      return 'Por completar';
    case 'por_corregir':
      return 'Por corregir';
    case 'error_sync':
      return 'Error de envio';
    case 'pendiente_sync':
      return 'Lista para sincronizar';
    case 'en_revision':
      return 'En revision';
    default:
      return 'Otras';
  }
}

String homeTaskSectionSubtitle(String sectionId) {
  switch (sectionId) {
    case 'por_iniciar':
      return 'Actividades listas para arrancar.';
    case 'en_curso':
      return 'Actividades con trabajo en progreso.';
    case 'por_completar':
      return 'Capturas pendientes de cerrar en wizard.';
    case 'por_corregir':
      return 'Items devueltos que requieren correccion.';
    case 'error_sync':
      return 'Requieren intervencion antes de volver a enviar.';
    case 'pendiente_sync':
      return 'Listas localmente, pendientes de subir al backend.';
    case 'en_revision':
      return 'Esperando decision de coordinacion.';
    default:
      return 'Items fuera de las bandejas principales.';
  }
}

List<HomeTaskSectionData> buildHomeTaskSections(
  List<TodayActivity> activities,
) {
  final buckets = <String, List<TodayActivity>>{
    for (final sectionId in _orderedSectionIds) sectionId: <TodayActivity>[],
  };

  for (final activity in activities) {
    final sectionId = homeTaskSectionIdForNextAction(activity.nextAction);
    buckets.putIfAbsent(sectionId, () => <TodayActivity>[]).add(activity);
  }

  final sections = <HomeTaskSectionData>[];
  for (final sectionId in _orderedSectionIds) {
    final items = buckets[sectionId] ?? const <TodayActivity>[];
    if (items.isEmpty) continue;

    final groupedByFrente = <String, List<TodayActivity>>{};
    for (final activity in items) {
      groupedByFrente
          .putIfAbsent(activity.frente, () => <TodayActivity>[])
          .add(activity);
    }

    final metrics = calculateSectionMetrics(sectionId, items);
    sections.add(
      HomeTaskSectionData(
        id: sectionId,
        items: List<TodayActivity>.unmodifiable(items),
        groupedByFrente: Map<String, List<TodayActivity>>.unmodifiable(
          groupedByFrente.map(
            (key, value) =>
                MapEntry(key, List<TodayActivity>.unmodifiable(value)),
          ),
        ),
        metrics: metrics,
      ),
    );
  }

  return List<HomeTaskSectionData>.unmodifiable(sections);
}

/// Calculate metrics for a task section
TaskSectionMetrics calculateSectionMetrics(
  String sectionId,
  List<TodayActivity> activities,
) {
  if (activities.isEmpty) {
    return TaskSectionMetrics.fromSectionId(
      sectionId,
      count: 0,
      completedCount: 0,
    );
  }

  // Count critical items based on status
  int criticalCount = 0;

  // For critical sections, all items are critical by definition
  if (sectionId == 'por_corregir' || sectionId == 'error_sync') {
    criticalCount = activities.length;
  }
  // For other sections, check for overdue activities
  else if (sectionId == 'por_completar') {
    // Items in 'por_completar' are somewhat urgent
    criticalCount = activities
        .where((a) => a.status == ActivityStatus.vencida)
        .length;
  }

  // Calculate average time in section (approximate based on creation time)
  Duration? averageTime;
  if (activities.isNotEmpty) {
    final now = DateTime.now();
    final totalDuration = activities.fold<Duration>(
      Duration.zero,
      (acc, activity) => acc + now.difference(activity.createdAt),
    );
    averageTime = Duration(
      milliseconds: totalDuration.inMilliseconds ~/ activities.length,
    );
  }

  return TaskSectionMetrics.fromSectionId(
    sectionId,
    count: activities.length,
    completedCount: 0, // TODO: implement completion tracking
    averageTime: averageTime,
    criticalCount: criticalCount,
  );
}
