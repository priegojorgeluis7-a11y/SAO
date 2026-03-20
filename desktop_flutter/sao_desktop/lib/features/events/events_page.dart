// lib/features/events/events_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/backend_api_client.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _EventRow {
  final String uuid;
  final String projectId;
  final String eventTypeCode;
  final String title;
  final String? description;
  final String severity;
  final int? locationPkMeters;
  final DateTime occurredAt;
  final DateTime? resolvedAt;
  final String reportedByUserId;
  final DateTime? deletedAt;

  const _EventRow({
    required this.uuid,
    required this.projectId,
    required this.eventTypeCode,
    required this.title,
    this.description,
    required this.severity,
    this.locationPkMeters,
    required this.occurredAt,
    this.resolvedAt,
    required this.reportedByUserId,
    this.deletedAt,
  });

  bool get isResolved => resolvedAt != null;

  factory _EventRow.fromJson(Map<String, dynamic> json) {
    return _EventRow(
      uuid: (json['uuid'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      eventTypeCode: (json['event_type_code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      severity: (json['severity'] ?? 'MEDIUM').toString(),
      locationPkMeters: json['location_pk_meters'] as int?,
      occurredAt: DateTime.tryParse((json['occurred_at'] ?? '').toString()) ??
          DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      reportedByUserId: (json['reported_by_user_id'] ?? '').toString(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _eventsProvider = FutureProvider.autoDispose
    .family<List<_EventRow>, String>((ref, projectId) async {
  try {
    final decoded = await const BackendApiClient()
        .getJson('/api/v1/events?project_id=$projectId&page_size=100');
    if (decoded is Map<String, dynamic> && decoded['items'] is List) {
      return (decoded['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => _EventRow.fromJson(e))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => _EventRow.fromJson(e))
          .toList();
    }
    return [];
  } catch (_) {
    return [];
  }
});

final _projectsListProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final decoded =
        await const BackendApiClient().getJson('/api/v1/catalog/projects');
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => (e['id'] ?? e['code'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return ['TMQ'];
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  String _selectedProject = 'TMQ';
  String _severityFilter = 'Todos';
  bool _showOnlyUnresolved = false;
  bool _isResolving = false;

  static const _severityOptions = [
    'Todos',
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL'
  ];

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(_projectsListProvider);
    final eventsAsync = ref.watch(_eventsProvider(_selectedProject));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Toolbar ──────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Eventos de Campo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              // Project selector
              projectsAsync.when(
                loading: () => const SizedBox(
                    width: 160, child: LinearProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (projects) {
                  final options = projects.isEmpty ? ['TMQ'] : projects;
                  final selected = options.contains(_selectedProject)
                      ? _selectedProject
                      : options.first;
                  return SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: selected,
                      decoration: const InputDecoration(
                        labelText: 'Proyecto',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: options
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedProject = v);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Severity filter
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  value: _severityFilter,
                  decoration: const InputDecoration(
                    labelText: 'Severidad',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _severityOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _severityFilter = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Unresolved filter
              FilterChip(
                label: const Text('Sin resolver'),
                selected: _showOnlyUnresolved,
                backgroundColor: AppColors.gray100,
                selectedColor: AppColors.primary.withValues(alpha: 0.14),
                checkmarkColor: AppColors.primary,
                labelStyle: const TextStyle(
                  color: AppColors.gray900,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: AppColors.gray300),
                onSelected: (v) => setState(() => _showOnlyUnresolved = v),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: () =>
                    ref.invalidate(_eventsProvider(_selectedProject)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Table ──────────────────────────────────────────────────
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: 'Error al cargar eventos: $e',
                onRetry: () =>
                    ref.invalidate(_eventsProvider(_selectedProject)),
              ),
              data: (events) {
                var filtered =
                    events.where((e) => e.deletedAt == null).toList();
                if (_severityFilter != 'Todos') {
                  filtered = filtered
                      .where((e) => e.severity == _severityFilter)
                      .toList();
                }
                if (_showOnlyUnresolved) {
                  filtered = filtered.where((e) => !e.isResolved).toList();
                }
                filtered.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

                if (filtered.isEmpty) {
                  return _EmptyState(projectId: _selectedProject);
                }

                return Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Tipo')),
                        DataColumn(label: Text('Severidad')),
                        DataColumn(label: Text('Título')),
                        DataColumn(label: Text('PK')),
                        DataColumn(label: Text('Fecha')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Acción')),
                      ],
                      rows: filtered.map((event) {
                        return DataRow(cells: [
                          DataCell(Text(
                            event.eventTypeCode,
                            style: const TextStyle(fontSize: 12),
                          )),
                          DataCell(_SeverityChip(severity: event.severity)),
                          DataCell(
                            Tooltip(
                              message: event.description ?? '',
                              child: Text(
                                event.title,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            showEditIcon: false,
                          ),
                          DataCell(Text(
                            event.locationPkMeters != null
                                ? _formatPk(event.locationPkMeters!)
                                : '—',
                            style: const TextStyle(fontSize: 12),
                          )),
                          DataCell(Text(
                            _formatDate(event.occurredAt),
                            style: const TextStyle(fontSize: 12),
                          )),
                          DataCell(_StatusChip(isResolved: event.isResolved)),
                          DataCell(
                            event.isResolved
                                ? const SizedBox.shrink()
                                : _isResolving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : TextButton(
                                        onPressed: () =>
                                            _markResolved(event.uuid),
                                        child: const Text('Resolver'),
                                      ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markResolved(String uuid) async {
    setState(() => _isResolving = true);
    try {
      await const BackendApiClient().patchJson(
        '/api/v1/events/$uuid',
        {'resolved_at': DateTime.now().toUtc().toIso8601String()},
      );
      if (mounted) {
        ref.invalidate(_eventsProvider(_selectedProject));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al resolver evento: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  String _formatPk(int meters) {
    final km = meters ~/ 1000;
    final m = meters % 1000;
    return '$km+${m.toString().padLeft(3, '0')}';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

  Color _foreground(String severity) {
    switch (severity) {
      case 'LOW':
        return const Color(0xFF14532D);
      case 'HIGH':
        return const Color(0xFF9A3412);
      case 'CRITICAL':
        return const Color(0xFF7F1D1D);
      default:
        return const Color(0xFF78350F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (severity) {
      'LOW' => ('BAJO', AppColors.riskLow),
      'HIGH' => ('ALTO', AppColors.riskHigh),
      'CRITICAL' => ('CRÍTICO', AppColors.riskCritical),
      _ => ('MEDIO', AppColors.riskMedium),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _foreground(severity),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isResolved;
  const _StatusChip({required this.isResolved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isResolved
            ? AppColors.success.withValues(alpha: 0.16)
            : AppColors.warning.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isResolved
              ? AppColors.success.withValues(alpha: 0.40)
              : AppColors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        isResolved ? 'Resuelto' : 'Abierto',
        style: TextStyle(
          color: isResolved ? const Color(0xFF065F46) : const Color(0xFF78350F),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String projectId;
  const _EmptyState({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: AppColors.gray300),
          const SizedBox(height: 16),
          const Text(
            'Sin eventos registrados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay eventos reportados para el proyecto $projectId.',
            style: const TextStyle(color: AppColors.gray500),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray700)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
