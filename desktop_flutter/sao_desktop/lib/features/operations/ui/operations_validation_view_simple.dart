// lib/features/operations/ui/operations_validation_view_simple.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/theme/sao_colors.dart';

// Simple Gap widget
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

// Modelo simplificado para demo
class OpItem {
  final String id;
  final String activity;
  final String date;
  final String time;
  final String risk; // bajo, medio, alto, prioritario
  final String location;
  final String responsible;
  final bool isNew;
  final String description;
  final String classification;

  OpItem({
    required this.id,
    required this.activity,
    required this.date,
    required this.time,
    required this.risk,
    required this.location,
    required this.responsible,
    this.isNew = false,
    required this.description,
    required this.classification,
  });
}

class OperationsValidationView extends StatefulWidget {
  const OperationsValidationView({super.key});

  @override
  State<OperationsValidationView> createState() => _OperationsValidationViewState();
}

class _OperationsValidationViewState extends State<OperationsValidationView> {
  int selectedIndex = 0;
  bool editedDescription = false;
  bool editedClassification = false;
  String filter = 'all';

  // 📱 Datos de demostración homologados con catálogo móvil
  late List<OpItem> items;

  @override
  void initState() {
    super.initState();
    items = [
      OpItem(
        id: '1',
        activity: 'Caminamiento',
        date: '2024-12-15',
        time: '09:30',
        risk: 'prioritario', // 📱 Homologado
        location: 'Chihuahua, Coyame del Sotol',
        responsible: 'María Hernández',
        isNew: true,
        description: 'Recorrido de verificación en zona rural',
        classification: 'Monitoreo electoral',
      ),
      OpItem(
        id: '2',
        activity: 'Reunión',
        date: '2024-12-15',
        time: '11:00',
        risk: 'alto',
        location: 'Durango, Gómez Palacio',
        responsible: 'Juan Pérez',
        isNew: false,
        description: 'Reunión con representantes locales',
        classification: 'Coordinación',
      ),
      OpItem(
        id: '3',
        activity: 'Asamblea',
        date: '2024-12-15',
        time: '14:00',
        risk: 'medio',
        location: 'Coahuila, Torreón',
        responsible: 'Ana Santos',
        isNew: false,
        description: 'Asamblea comunitaria',
        classification: 'Participación ciudadana',
      ),
      OpItem(
        id: '4',
        activity: 'Caminamiento',
        date: '2024-12-15',
        time: '16:30',
        risk: 'bajo',
        location: 'Chihuahua, Chihuahua',
        responsible: 'Carlos Ramírez',
        isNew: true,
        description: 'Inspección de casillas',
        classification: 'Logística electoral',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Scaffold(
        backgroundColor: SaoColors.surfaceDim,
        body: Center(
          child: Text(
            'No hay actividades pendientes',
            style: TextStyle(color: SaoColors.gray600),
          ),
        ),
      );
    }

    final item = items[selectedIndex];

    return Scaffold(
      backgroundColor: SaoColors.surfaceDim,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyA): () => _approveAndNext(),
          const SingleActivator(LogicalKeyboardKey.keyR): () => _showRejectDialog(context),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _goPrevious(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _goNext(),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      // IZQUIERDA - Cola de Trabajo
                      Expanded(
                        flex: 20,
                        child: _LeftInbox(
                          items: _applyFilter(items, filter),
                          selectedId: item.id,
                          filter: filter,
                          onFilterChanged: (v) => setState(() => filter = v),
                          onSelect: (id) {
                            final idx = items.indexWhere((e) => e.id == id);
                            if (idx != -1) setState(() => selectedIndex = idx);
                          },
                        ),
                      ),
                      const Gap(12),
                      // CENTRO - Formulario
                      Expanded(
                        flex: 30,
                        child: _CenterForm(
                          item: item,
                          editedDescription: editedDescription,
                          editedClassification: editedClassification,
                          onEditDescription: () => setState(() => editedDescription = true),
                          onEditClassification: () => setState(() => editedClassification = true),
                        ),
                      ),
                      const Gap(12),
                      // DERECHA - Evidencia
                      Expanded(
                        flex: 50,
                        child: _RightEvidence(item: item),
                      ),
                    ],
                  ),
                ),
              ),
              _FooterActions(
                onPrev: selectedIndex > 0 ? _goPrevious : null,
                onNext: selectedIndex < items.length - 1 ? _goNext : null,
                onReject: () => _showRejectDialog(context),
                onApprove: _approveAndNext,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<OpItem> _applyFilter(List<OpItem> list, String filter) {
    switch (filter) {
      case 'new':
        return list.where((e) => e.isNew).toList();
      case 'today':
        return list;
      case 'high':
        return list.where((e) => ['alto', 'prioritario'].contains(e.risk)).toList();
      default:
        return list;
    }
  }

  void _goPrevious() {
    if (selectedIndex > 0) {
      setState(() => selectedIndex--);
    }
  }

  void _goNext() {
    if (selectedIndex < items.length - 1) {
      setState(() => selectedIndex++);
    }
  }

  void _approveAndNext() {
    if (selectedIndex < items.length - 1) {
      setState(() => selectedIndex++);
    }
  }

  void _showRejectDialog(BuildContext context) {
    final reasons = [
      'Foto borrosa',
      'Ubicación incorrecta',
      'Falta información',
      'Clasificación errónea',
      'Otro',
    ];
    String? selected = reasons.first;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: SaoColors.surface,
          surfaceTintColor: SaoColors.surface,
          title: const Text('Rechazar actividad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                items: reasons
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => selected = v,
                decoration: _fieldDeco(label: 'Motivo', icon: Icons.report_gmailerrorred),
              ),
              const Gap(12),
              TextField(
                maxLines: 3,
                decoration: _fieldDeco(
                  label: 'Comentario (opcional)',
                  icon: Icons.edit_note,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SaoColors.error,
                foregroundColor: SaoColors.onPrimary,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        border: Border(bottom: BorderSide(color: SaoColors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_note, color: SaoColors.gray700, size: 22),
          const Gap(8),
          Text(
            'Validación de Operaciones',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SaoColors.gray900,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings, color: SaoColors.gray600),
            onPressed: () {},
            tooltip: 'Configuración',
          ),
        ],
      ),
    );
  }
}

class _LeftInbox extends StatelessWidget {
  const _LeftInbox({
    required this.items,
    required this.selectedId,
    required this.filter,
    required this.onFilterChanged,
    required this.onSelect,
  });

  final List<OpItem> items;
  final String selectedId;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        border: Border.all(color: SaoColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: SaoColors.border),
          _buildFilters(context),
          const Divider(height: 1, color: SaoColors.border),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: SaoColors.border),
              itemBuilder: (_, i) {
                final item = items[i];
                final isSelected = item.id == selectedId;
                return InkWell(
                  onTap: () => onSelect(item.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: isSelected ? SaoColors.actionPrimary.withOpacity(0.08) : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.activity,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: SaoColors.gray900,
                                    ),
                              ),
                            ),
                            if (item.isNew)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: SaoColors.actionPrimary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'NUEVO',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: SaoColors.onPrimary,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const Gap(4),
                        Text(
                          '${item.date} ${item.time}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: SaoColors.gray600),
                        ),
                        const Gap(4),
                        // 📱 Indicador de riesgo homologado (círculo coloreado)
                        _RiskPill(risk: item.risk),
                      ],
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.inbox, color: SaoColors.gray700, size: 18),
          const Gap(6),
          Text(
            'Cola de Trabajo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SaoColors.gray900,
                ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SaoColors.actionPrimary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${items.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: SaoColors.onPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final filters = [
      {'id': 'all', 'label': 'Todos', 'icon': Icons.list},
      {'id': 'new', 'label': 'Nuevos', 'icon': Icons.fiber_new},
      {'id': 'today', 'label': 'Hoy', 'icon': Icons.today},
      {'id': 'high', 'label': 'Alto Riesgo', 'icon': Icons.warning},
    ];

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: filters.map((f) {
          final isActive = filter == f['id'];
          return InkWell(
            onTap: () => onFilterChanged(f['id'] as String),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? SaoColors.actionPrimary : SaoColors.gray100,
                border: Border.all(
                  color: isActive ? SaoColors.actionPrimary : SaoColors.border,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f['icon'] as IconData,
                    size: 12,
                    color: isActive ? SaoColors.onPrimary : SaoColors.gray700,
                  ),
                  const Gap(4),
                  Text(
                    f['label'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isActive ? SaoColors.onPrimary : SaoColors.gray700,
                        ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 📱 Indicador de riesgo homologado con app móvil (círculo + texto)
class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.risk});
  final String risk;

  @override
  Widget build(BuildContext context) {
    final color = _getRiskColor(risk);
    final label = _getRiskLabel(risk);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const Gap(6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'bajo':
        return SaoColors.riskLow;
      case 'medio':
        return SaoColors.riskMedium;
      case 'alto':
        return SaoColors.riskHigh;
      case 'prioritario':
        return SaoColors.riskCritical; // Todavía se llama riskCritical en colors
      default:
        return SaoColors.gray500;
    }
  }

  String _getRiskLabel(String risk) {
    switch (risk.toLowerCase()) {
      case 'bajo':
        return 'BAJO';
      case 'medio':
        return 'MEDIO';
      case 'alto':
        return 'ALTO';
      case 'prioritario':
        return 'PRIORITARIO'; // 📱 Homologado
      default:
        return risk.toUpperCase();
    }
  }
}

class _CenterForm extends StatelessWidget {
  const _CenterForm({
    required this.item,
    required this.editedDescription,
    required this.editedClassification,
    required this.onEditDescription,
    required this.onEditClassification,
  });

  final OpItem item;
  final bool editedDescription;
  final bool editedClassification;
  final VoidCallback onEditDescription;
  final VoidCallback onEditClassification;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        border: Border.all(color: SaoColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verdad Técnica',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SaoColors.gray900,
                  ),
            ),
            const Gap(16),
            _buildField(
              label: 'Actividad',
              value: item.activity,
              icon: Icons.event,
            ),
            const Gap(12),
            _buildField(
              label: 'Fecha y Hora',
              value: '${item.date} ${item.time}',
              icon: Icons.schedule,
            ),
            const Gap(12),
            _buildField(
              label: 'Ubicación',
              value: item.location,
              icon: Icons.location_on,
            ),
            const Gap(12),
            _buildField(
              label: 'Responsable',
              value: item.responsible,
              icon: Icons.person,
            ),
            const Gap(12),
            // 📱 Nivel de riesgo con indicador circular
            _buildRiskField(item.risk),
            const Gap(16),
            const Divider(color: SaoColors.border),
            const Gap(16),
            TextField(
              controller: TextEditingController(text: item.description),
              maxLines: 3,
              onChanged: (_) => onEditDescription(),
              decoration: _fieldDeco(
                label: 'Descripción',
                icon: Icons.description,
                suffix: editedDescription
                    ? Chip(
                        label: Text(
                          'Editado',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              ),
            ),
            const Gap(12),
            TextField(
              controller: TextEditingController(text: item.classification),
              onChanged: (_) => onEditClassification(),
              decoration: _fieldDeco(
                label: 'Clasificación',
                icon: Icons.category,
                suffix: editedClassification
                    ? Chip(
                        label: Text(
                          'Editado',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: SaoColors.gray600),
            const Gap(6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: SaoColors.gray600,
                  ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SaoColors.gray900,
              ),
        ),
      ],
    );
  }

  Widget _buildRiskField(String risk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning, size: 14, color: SaoColors.gray600),
            const Gap(6),
            Text(
              'Nivel de Riesgo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: SaoColors.gray600,
                  ),
            ),
          ],
        ),
        const Gap(8),
        _RiskPill(risk: risk),
      ],
    );
  }
}

class _RightEvidence extends StatelessWidget {
  const _RightEvidence({required this.item});
  final OpItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        border: Border.all(color: SaoColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library, color: SaoColors.gray700, size: 18),
              const Gap(8),
              Text(
                'Evidencia Visual',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SaoColors.gray900,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.fullscreen, size: 16),
                label: Text('Ver completo'),
                style: TextButton.styleFrom(
                  foregroundColor: SaoColors.actionPrimary,
                ),
              ),
            ],
          ),
          const Gap(16),
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SaoColors.gray100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 64,
                      color: SaoColors.gray400,
                    ),
                    const Gap(8),
                    Text(
                      'Foto de evidencia',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SaoColors.gray600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.onPrev,
    required this.onNext,
    required this.onReject,
    required this.onApprove,
  });

  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        border: Border(top: BorderSide(color: SaoColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Anterior (←)',
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Siguiente (→)',
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close),
            label: const Text('Rechazar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SaoColors.error,
              side: BorderSide(color: SaoColors.error),
            ),
          ),
          const Gap(12),
          FilledButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check),
            label: const Text('Aprobar'),
            style: FilledButton.styleFrom(
              backgroundColor: SaoColors.actionPrimary,
              foregroundColor: SaoColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDeco({
  required String label,
  required IconData icon,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18),
    suffix: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: SaoColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: SaoColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: SaoColors.actionPrimary, width: 2),
    ),
    filled: true,
    fillColor: SaoColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
