// lib/features/events/ui/report_event_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme/sao_colors.dart';
import '../data/events_provider.dart';
import '../models/event_dto.dart';
import '../../../core/utils/uuid.dart' show uuidV4;

/// Three-step bottom sheet for field event reporting.
///
/// Step 1 — Event type + severity
/// Step 2 — Description + PK location
/// Step 3 — Confirmation summary
Future<void> showReportEventSheet(
  BuildContext context, {
  required String projectId,
  required String reportedByUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: SaoColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      child: _ReportEventSheet(
        projectId: projectId,
        reportedByUserId: reportedByUserId,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Internal widget
// ─────────────────────────────────────────────

class _ReportEventSheet extends ConsumerStatefulWidget {
  final String projectId;
  final String reportedByUserId;

  const _ReportEventSheet({
    required this.projectId,
    required this.reportedByUserId,
  });

  @override
  ConsumerState<_ReportEventSheet> createState() => _ReportEventSheetState();
}

class _ReportEventSheetState extends ConsumerState<_ReportEventSheet> {
  final _pageController = PageController();
  int _step = 0; // 0, 1, 2

  // Step 1 fields
  String _eventTypeCode = 'DERRAME';
  EventSeverity _severity = EventSeverity.medium;

  // Step 2 fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pkCtrl = TextEditingController();

  // Form keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  static const _eventTypes = [
    ('DERRAME', 'Derrame / Fuga', Icons.water_damage_rounded),
    ('ACCIDENTE', 'Accidente', Icons.personal_injury_rounded),
    ('BLOQUEO', 'Bloqueo de vía', Icons.block_rounded),
    ('INCENDIO', 'Incendio', Icons.local_fire_department_rounded),
    ('VANDALISMO', 'Vandalismo', Icons.warning_rounded),
    ('FALLA_EQUIPO', 'Falla de equipo', Icons.build_rounded),
    ('OTRO', 'Otro', Icons.report_problem_rounded),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pkCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && !(_step1Key.currentState?.validate() ?? false)) return;
    if (_step == 1 && !(_step2Key.currentState?.validate() ?? false)) return;
    if (_step < 2) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _submit() async {
    final dto = EventDTO(
      uuid: uuidV4(),
      projectId: widget.projectId,
      reportedByUserId: widget.reportedByUserId,
      eventTypeCode: _eventTypeCode,
      title: _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : _eventTypeLabel(_eventTypeCode),
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      severity: _severity.value,
      locationPkMeters: _pkCtrl.text.trim().isNotEmpty
          ? int.tryParse(_pkCtrl.text.trim())
          : null,
      occurredAt: DateTime.now().toUtc().toIso8601String(),
    );

    await ref.read(reportEventControllerProvider.notifier).submit(dto);
  }

  String _eventTypeLabel(String code) {
    return _eventTypes
        .firstWhere(
          (t) => t.$1 == code,
          orElse: () => (code, code, Icons.report_rounded),
        )
        .$2;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportEventControllerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    ref.listen(reportEventControllerProvider, (_, next) {
      if (next.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Evento registrado — se sincronizará cuando haya red'),
            backgroundColor: SaoColors.success,
          ),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _prevStep,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Reportar evento',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        _StepIndicator(currentStep: _step, totalSteps: 3),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step1(
                    formKey: _step1Key,
                    selectedType: _eventTypeCode,
                    severity: _severity,
                    eventTypes: _eventTypes,
                    onTypeChanged: (v) => setState(() => _eventTypeCode = v),
                    onSeverityChanged: (v) => setState(() => _severity = v),
                  ),
                  _Step2(
                    formKey: _step2Key,
                    titleCtrl: _titleCtrl,
                    descCtrl: _descCtrl,
                    pkCtrl: _pkCtrl,
                  ),
                  _Step3(
                    eventTypeLabel: _eventTypeLabel(_eventTypeCode),
                    severity: _severity,
                    title: _titleCtrl.text.trim(),
                    description: _descCtrl.text.trim(),
                    pkMeters: int.tryParse(_pkCtrl.text.trim()),
                    projectId: widget.projectId,
                  ),
                ],
              ),
            ),

            // ── Bottom action ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: state.isSubmitting
                      ? null
                      : (_step < 2 ? _nextStep : _submit),
                  style: FilledButton.styleFrom(
                    backgroundColor: _step == 2
                        ? SaoColors.riskHigh
                        : SaoColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step < 2 ? 'Siguiente' : 'Confirmar reporte',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 1 — Tipo + Severidad
// ─────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String selectedType;
  final EventSeverity severity;
  final List<(String, String, IconData)> eventTypes;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<EventSeverity> onSeverityChanged;

  const _Step1({
    required this.formKey,
    required this.selectedType,
    required this.severity,
    required this.eventTypes,
    required this.onTypeChanged,
    required this.onSeverityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de evento',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: SaoColors.gray600,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            ...eventTypes.map((t) => _TypeTile(
                  code: t.$1,
                  label: t.$2,
                  icon: t.$3,
                  selected: selectedType == t.$1,
                  onTap: () => onTypeChanged(t.$1),
                )),
            const SizedBox(height: 20),
            Text(
              'Severidad',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: SaoColors.gray600,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            _SeveritySelector(
              selected: severity,
              onChanged: onSeverityChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String code;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.code,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? SaoColors.primary : SaoColors.gray100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? SaoColors.primary : SaoColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? SaoColors.onPrimary : SaoColors.gray600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? SaoColors.onPrimary : SaoColors.gray800,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: SaoColors.onPrimary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SeveritySelector extends StatelessWidget {
  final EventSeverity selected;
  final ValueChanged<EventSeverity> onChanged;

  const _SeveritySelector({required this.selected, required this.onChanged});

  static const _options = [
    (EventSeverity.low, SaoColors.riskLow),
    (EventSeverity.medium, SaoColors.riskMedium),
    (EventSeverity.high, SaoColors.riskHigh),
    (EventSeverity.critical, SaoColors.riskCritical),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final isSelected = opt.$1 == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? opt.$2 : SaoColors.gray100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? opt.$2 : SaoColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    opt.$1.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : SaoColors.gray700,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// Step 2 — Descripción + PK
// ─────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController pkCtrl;

  const _Step2({
    required this.formKey,
    required this.titleCtrl,
    required this.descCtrl,
    required this.pkCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Título (opcional)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: SaoColors.gray600,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: titleCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Ej: Derrame de combustible en km 142',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: SaoColors.gray600,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: descCtrl,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Describe el evento con el mayor detalle posible...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ubicación PK (metros)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: SaoColors.gray600,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: pkCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Ej: 142000',
                prefixIcon: Icon(Icons.place_rounded),
                border: OutlineInputBorder(),
                helperText: 'Ingresa el PK en metros (ej: 142+000 → 142000)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 3 — Confirmación
// ─────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final String eventTypeLabel;
  final EventSeverity severity;
  final String title;
  final String description;
  final int? pkMeters;
  final String projectId;

  const _Step3({
    required this.eventTypeLabel,
    required this.severity,
    required this.title,
    required this.description,
    required this.pkMeters,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SaoColors.riskHighBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SaoColors.riskHigh.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: SaoColors.riskHigh),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Revisa la información antes de enviar. El reporte quedará guardado localmente y se sincronizará con el servidor cuando haya conexión.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SaoColors.gray700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SummaryRow(label: 'Proyecto', value: projectId),
          _SummaryRow(label: 'Tipo', value: eventTypeLabel),
          _SummaryRow(
            label: 'Severidad',
            value: severity.label,
            valueColor: SaoColors.getRiskColor(severity.value),
          ),
          if (title.isNotEmpty) _SummaryRow(label: 'Título', value: title),
          if (description.isNotEmpty)
            _SummaryRow(label: 'Descripción', value: description),
          if (pkMeters != null)
            _SummaryRow(
              label: 'Ubicación PK',
              value: _formatPk(pkMeters!),
            ),
          _SummaryRow(
            label: 'Fecha/Hora',
            value: _formatNow(),
          ),
        ],
      ),
    );
  }

  String _formatPk(int meters) {
    final km = meters ~/ 1000;
    final m = meters % 1000;
    return '$km+${m.toString().padLeft(3, '0')} ($meters m)';
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: SaoColors.gray500,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? SaoColors.gray800,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final active = i == currentStep;
        final done = i < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: done || active ? SaoColors.primary : SaoColors.gray300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
