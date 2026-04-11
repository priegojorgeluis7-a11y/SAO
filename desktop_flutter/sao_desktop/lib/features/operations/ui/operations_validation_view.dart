// lib/features/operations/ui/operations_validation_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme/sao_colors.dart';
import '../providers/operations_provider.dart';
import '../../../data/repositories/catalog_repository.dart';

// Simple Gap widget (reemplaza gap package)
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

class OperationsValidationView extends ConsumerStatefulWidget {
  const OperationsValidationView({super.key});

  @override
  ConsumerState<OperationsValidationView> createState() => _OperationsValidationViewState();
}

class _OperationsValidationViewState extends ConsumerState<OperationsValidationView> {
  int selectedIndex = 0;

  // Edición: marca campos tocados (para "Editado en oficina")
  bool editedDescription = false;
  bool editedClassification = false;

  // Chips
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final operationsAsync = ref.watch(operationsDataProvider);
    
    return operationsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: SaoColors.surfaceDim,
        body: Center(
          child: CircularProgressIndicator(color: SaoColors.actionPrimary),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: SaoColors.surfaceDim,
        body: Center(
          child: Text('Error: $error', style: const TextStyle(color: SaoColors.error)),
        ),
      ),
      data: (operationsData) {
        final items = operationsData.operationItems;
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
              // Atajos de teclado para revisión rápida.
              const SingleActivator(LogicalKeyboardKey.keyA): () => _approveAndNext(items),
              const SingleActivator(LogicalKeyboardKey.keyR): () => _showRejectDialog(context),
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _goPrevious(items),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () => _goNext(items),
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
                          Expanded(
                            flex: 20,
                            child: _LeftInbox(
                              items: _applyFilter(items, filter),
                              selectedId: item.id,
                              filter: filter,
                              onFilterChanged: (v) => setState(() => filter = v),
                              onSelect: (id) {
                                final idx = items.indexWhere((e) => e.id == id);
                                if (idx != -1) {
                                  setState(() => selectedIndex = idx);
                                }
                              },
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            flex: 30,
                            child: _CenterForm(
                              item: item,
                              catalogRepo: operationsData.catalogRepo,
                              editedDescription: editedDescription,
                              editedClassification: editedClassification,
                              onEditDescription: () => setState(() => editedDescription = true),
                              onEditClassification: () => setState(() => editedClassification = true),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            flex: 50,
                            child: _RightEvidence(item: item),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _FooterActions(
                    onPrev: selectedIndex > 0 ? () => _goPrevious(items) : null,
                    onNext: selectedIndex < items.length - 1 ? () => _goNext(items) : null,
                    onReject: () => _showRejectDialog(context),
                    onApprove: () => _approveAndNext(items),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<OperationItem> _applyFilter(List<OperationItem> list, String filter) {
    switch (filter) {
      case 'new':
        return list.where((e) => e.isNew).toList();
      case 'today':
        return list; // TODO: filtrar por fecha real
      case 'high':
        return list.where((e) => ['high', 'critical'].contains(e.risk)).toList();
      default:
        return list;
    }
  }

  void _goPrevious(List<OperationItem> items) {
    if (selectedIndex > 0) {
      setState(() => selectedIndex--);
    }
  }

  void _goNext(List<OperationItem> items) {
    if (selectedIndex < items.length - 1) {
      setState(() => selectedIndex++);
    }
  }

  void _approveAndNext(List<OperationItem> items) {
    // TODO: ejecutar acción real (API/DB)
    // y avanzar a siguiente si existe
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
                initialValue: selected,
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
                // TODO: guardar rechazo real
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
      decoration: const BoxDecoration(
        color: SaoColors.surface,
        border: Border(bottom: BorderSide(color: SaoColors.border)),
      ),
      child: const Row(
        children: [
          Icon(Icons.railway_alert, color: SaoColors.actionPrimary),
          Gap(10),
          Text(
            'SAO • Operaciones • Validación',
            style: TextStyle(
              color: SaoColors.actionPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Spacer(),
          _Pill(
            icon: Icons.cloud_done,
            text: 'Sincronización OK',
            color: SaoColors.success,
            bg: SaoColors.gray100,
          ),
          Gap(8),
          _Pill(
            icon: Icons.account_circle,
            text: 'Coordinador',
            color: SaoColors.gray700,
            bg: SaoColors.gray100,
          ),
          Gap(8),
          Flexible(
            child: _Pill(
              icon: Icons.keyboard,
              text: 'A=Aprobar • R=Rechazar',
              color: SaoColors.actionPrimary,
              bg: SaoColors.gray50,
            ),
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

  final List<OperationItem> items;
  final String selectedId;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Bandeja de entrada',
      subtitle: '${items.length} pendientes',
      headerTrailing: IconButton(
        tooltip: 'Actualizar',
        onPressed: () {},
        icon: const Icon(Icons.refresh, color: SaoColors.gray700),
      ),
      child: Column(
        children: [
          _ChipRow(
            value: filter,
            onChanged: onFilterChanged,
          ),
          const Gap(12),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Gap(8),
              itemBuilder: (_, i) {
                final it = items[i];
                final selected = it.id == selectedId;
                final riskColor = SaoColors.getRiskColor(it.risk);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(it.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? SaoColors.actionPrimary.withValues(alpha: 0.04)
                          : SaoColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? SaoColors.actionPrimary.withValues(alpha: 0.3)
                            : SaoColors.border,
                        width: selected ? 1.2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SaoColors.gray900.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 54,
                          decoration: BoxDecoration(
                            color: riskColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      it.type,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: selected ? SaoColors.actionPrimary : SaoColors.primary,  // 🎯 Azul marino cuando selected
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (it.isNew)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: SaoColors.actionPrimary,  // 🎯 Azul marino para nuevos
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                ],
                              ),
                              const Gap(2),
                              Text(
                                '${it.pk} • ${it.engineer}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: SaoColors.gray600),
                              ),
                              const Gap(6),
                              Row(
                                children: [
                                  const Icon(Icons.cloud, size: 14, color: SaoColors.gray500),
                                  const Gap(4),
                                  Text(
                                    'Sincronizado hace ${it.syncedAgo}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: SaoColors.gray500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
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
}

class _CenterForm extends StatelessWidget {
  const _CenterForm({
    required this.item,
    required this.catalogRepo,
    required this.editedDescription,
    required this.editedClassification,
    required this.onEditDescription,
    required this.onEditClassification,
  });

  final OperationItem item;
  final CatalogRepository catalogRepo;
  final bool editedDescription;
  final bool editedClassification;
  final VoidCallback onEditDescription;
  final VoidCallback onEditClassification;

  @override
  Widget build(BuildContext context) {
    final gpsOk = item.gpsDeltaMeters <= 5;
    final gpsWarn = item.gpsDeltaMeters > 5 && item.gpsDeltaMeters <= 100;

    final alertBg = gpsOk
      ? SaoColors.success.withValues(alpha: 0.10)
        : gpsWarn
            ? SaoColors.alertBg
        : SaoColors.error.withValues(alpha: 0.10);

    final alertBorder = gpsOk
      ? SaoColors.success.withValues(alpha: 0.35)
        : gpsWarn
            ? SaoColors.alertBorder
        : SaoColors.error.withValues(alpha: 0.35);

    final alertText = gpsOk
        ? SaoColors.success
        : gpsWarn
            ? SaoColors.alertText
            : SaoColors.error;

    final alertIcon = gpsOk
        ? Icons.check_circle
        : gpsWarn
            ? Icons.warning_amber_rounded
            : Icons.dangerous;

    final alertMsg = gpsOk
        ? 'GPS coincide con PK (margen ${item.gpsDeltaMeters}m)'
        : gpsWarn
            ? 'GPS desviado ${item.gpsDeltaMeters}m del PK reportado'
            : 'GPS desviado ${item.gpsDeltaMeters}m • Posible inconsistencia';

    return _Panel(
      title: 'Datos técnicos',
      subtitle: 'Validación y corrección',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PK + Alerta GPS (CRÍTICO)
            Text('PK reportado', style: _labelStyle(context)),
            const Gap(6),
            _ValuePill(text: item.pk),
            const Gap(10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: alertBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: alertBorder),
              ),
              child: Row(
                children: [
                  Icon(alertIcon, color: alertText),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      alertMsg,
                      style: TextStyle(
                        color: alertText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(14),

            // Datos Editables (más rápido corregir que rechazar)
            const _SectionTitle('Información editable'),
            const Gap(10),

            DropdownButtonFormField<String>(
              initialValue: item.type,
              items: catalogRepo.getActivityTypes()
                  .map((activity) => DropdownMenuItem(
                        value: activity.name, 
                        child: Text(activity.name),
                      ))
                  .toList(),
              onChanged: (_) {},
              decoration: _fieldDeco(label: 'Tipo de actividad', icon: Icons.category),
            ),
            const Gap(12),

            DropdownButtonFormField<String>(
              initialValue: item.classification,
              items: const [
                DropdownMenuItem(value: 'Ambiental', child: Text('Ambiental')),
                DropdownMenuItem(value: 'Social', child: Text('Social')),
                DropdownMenuItem(value: 'Jurídico', child: Text('Jurídico')),
                DropdownMenuItem(value: 'Técnico', child: Text('Técnico')),
              ],
              onChanged: (_) => onEditClassification(),
              decoration: _fieldDeco(
                label: 'Clasificación',
                icon: Icons.badge_outlined,
                edited: editedClassification,  // 🎯 Marca como "editado en oficina"
              ),
            ),
            const Gap(12),

            TextField(
              onChanged: (_) => onEditDescription(),
              maxLines: 4,
              decoration: _fieldDeco(
                label: 'Descripción',
                icon: Icons.description_outlined,
                edited: editedDescription,  // 🎯 Marca como "editado en oficina"
              ),
            ),
            const Gap(14),

            // Metadatos (duración automática)
            const _SectionTitle('Información adicional'),
            const Gap(10),
            _KeyValueRow('Estado', item.state),
            _KeyValueRow('Municipio', item.municipality),
            const _KeyValueRow('Hora inicio', '08:15'),
            const _KeyValueRow('Hora fin', '10:30'),
            const _KeyValueRow('Duración', '2h 15m'),
            const Gap(14),

            const _SectionTitle('Riesgo'),
            const Gap(10),
            Row(
              children: [
                _RiskPill(
                  text: SaoColors.getRiskLabel(item.risk),
                  color: SaoColors.getRiskColor(item.risk),
                  bg: SaoColors.getRiskBackground(item.risk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RightEvidence extends StatelessWidget {
  const _RightEvidence({required this.item});
  final OperationItem item;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Evidencias',
      subtitle: 'Fotografías y ubicación',
      child: Column(
        children: [
          // Foto principal GIGANTE (El Ojo Clínico)
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: SaoColors.gray100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SaoColors.border),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo, size: 56, color: SaoColors.gray400),
                        Gap(8),
                        Text(
                          'Fotografía del muro de contención',
                          style: TextStyle(color: SaoColors.gray600),
                        ),
                      ],
                    ),
                  ),
                ),
                // Herramientas flotantes: Zoom, Rotar, Brillo
                const Positioned(
                  top: 12,
                  right: 12,
                  child: _FloatingTools(),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _Pill(
                    icon: Icons.place,
                    text: '${item.state}, ${item.municipality}',
                    color: SaoColors.gray700,
                    bg: SaoColors.gray50,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),

          // Mini-Mapa de Contexto (Trazo + Pin)
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: SaoColors.gray100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SaoColors.border),
              ),
              child: Stack(
                children: [
                    Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_outlined, size: 46, color: SaoColors.gray400),
                        const Gap(8),
                        Text(
                          'Mapa: Trazo de vía + Ubicación del reporte',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: SaoColors.gray600),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: _Pill(
                      icon: Icons.route,
                      text: 'Dentro del Derecho de Vía',
                      color: SaoColors.success,
                      bg: SaoColors.gray50,
                    ),
                  ),
                ],
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
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        border: const Border(top: BorderSide(color: SaoColors.border)),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Anterior (←)',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, color: SaoColors.gray700),
          ),
          IconButton(
            tooltip: 'Siguiente (→)',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: SaoColors.gray700),
          ),
          const Spacer(),
          // Botón RECHAZAR (Blanco/Borde Rojo)
          OutlinedButton.icon(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: SaoColors.error,
              side: BorderSide(color: SaoColors.error.withValues(alpha: 0.7)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.close),
            label: const Text('Rechazar [R]'),
          ),
          const Gap(12),
          // Botón APROBAR (Azul Marino Sólido) 🎯 EL BOTÓN PROTAGONISTA
          FilledButton.icon(
            onPressed: onApprove,
            style: FilledButton.styleFrom(
              backgroundColor: SaoColors.actionPrimary,  // 🎯 ¡EL AZUL MARINO ELEGANTE!
              foregroundColor: SaoColors.onActionPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.check),
            label: const Text('APROBAR [A]'),
          ),
        ],
      ),
    );
  }
}

// ========================
// COMPONENTES BASE
// ========================

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SaoColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                            style: const TextStyle(
                            color: SaoColors.actionPrimary,  // 🎯 Headers en azul marino
                            fontWeight: FontWeight.w800,
                          )),
                      const Gap(2),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: SaoColors.gray600),
                      ),
                    ],
                  ),
                ),
                if (headerTrailing != null) headerTrailing!,
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'Todos',
          value: 'all',
          selected: value == 'all',
          onTap: () => onChanged('all'),
        ),
        _FilterChip(
          label: '⚠️ Riesgo Alto',
          value: 'high',
          selected: value == 'high',
          onTap: () => onChanged('high'),
        ),
        _FilterChip(
          label: '📅 Hoy',
          value: 'today',
          selected: value == 'today',
          onTap: () => onChanged('today'),
        ),
        _FilterChip(
          label: '🆕 Nuevos',
          value: 'new',
          selected: value == 'new',
          onTap: () => onChanged('new'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? SaoColors.actionPrimary.withValues(alpha: 0.08)
              : SaoColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? SaoColors.actionPrimary.withValues(alpha: 0.3)
                : SaoColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? SaoColors.actionPrimary : SaoColors.gray800,  // 🎯 Texto azul marino cuando selected
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _FloatingTools extends StatelessWidget {
  const _FloatingTools();

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tooltip) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 18, color: SaoColors.gray700),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        btn(Icons.zoom_in, 'Ampliar'),
        const Gap(8),
        btn(Icons.rotate_right, 'Rotar'),
        const Gap(8),
        btn(Icons.brightness_6, 'Brillo para túneles'),
      ],
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.text, required this.color, required this.bg});
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SaoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 📱 Punto de color como en app móvil (en lugar de ícono)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const Gap(8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color, required this.bg});
  final IconData icon;
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SaoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const Gap(6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SaoColors.gray800,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SaoColors.actionPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaoColors.actionPrimary.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: SaoColors.actionPrimary,  // 🎯 Texto azul marino
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: SaoColors.gray800,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 92,
            child: SizedBox(),
          ),
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: SaoColors.gray600),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: SaoColors.gray800, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _labelStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(
          color: SaoColors.gray600,
          fontWeight: FontWeight.w600,
        ) ??
    const TextStyle(
      color: SaoColors.gray600,
      fontWeight: FontWeight.w600,
    );

InputDecoration _fieldDeco({
  required String label,
  required IconData icon,
  bool edited = false,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: SaoColors.gray500),
    filled: true,
    fillColor: edited
        ? SaoColors.warning.withValues(alpha: 0.14)
        : SaoColors.gray50,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: edited
            ? SaoColors.warning.withValues(alpha: 0.5)
            : SaoColors.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: SaoColors.actionPrimary.withValues(alpha: 0.7),
        width: 1.3,
      ),
    ),
  );
}