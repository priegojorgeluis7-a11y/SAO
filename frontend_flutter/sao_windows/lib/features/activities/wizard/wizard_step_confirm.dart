// lib/features/activities/wizard/wizard_step_confirm.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/snackbar.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import 'wizard_controller.dart';

class WizardStepConfirm extends StatelessWidget {
  final WizardController controller;
  final VoidCallback onBack;
  final void Function(int step) onJumpToStep;

  const WizardStepConfirm({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onJumpToStep,
  });

  @override
  Widget build(BuildContext context) {
    final a = controller.activity;

    final riskText = switch (controller.risk) {
      RiskLevel.bajo => 'Bajo',
      RiskLevel.medio => 'Medio',
      RiskLevel.alto => 'Alto',
      RiskLevel.prioritario => 'Prioritario',
      null => '—',
    };

    final riskColor = switch (controller.risk) {
      RiskLevel.bajo => SaoColors.riskLow,
      RiskLevel.medio => SaoColors.riskMedium,
      RiskLevel.alto => SaoColors.riskHigh,
      RiskLevel.prioritario => SaoColors.riskPriority,
      null => SaoColors.gray400,
    };

    final sub = controller.selectedSubcategory?.name ?? '—';
    final pur = controller.selectedPurpose?.name ?? '—';
    
    // Limpiar resultado: quitar prefijo "R01 - "
    final rawRes = controller.selectedResult?.name ?? '—';
    final res = rawRes.contains(' - ') ? rawRes.split(' - ').last.trim() : rawRes;

    // Temas: mostrar nombres si son pocos, de lo contrario mostrar conteo
    final topicsList = controller.topics
        .where((t) => controller.selectedTopicIds.contains(t.id))
        .map((t) => t.name)
        .toList();
    final topicsText = topicsList.isEmpty
        ? 'Ninguno'
        : topicsList.length <= 3
            ? topicsList.join(', ')
            : '${topicsList.length} temas seleccionados';

    // Asistentes: mostrar nombres si son pocos
    final attendeesList = [
      ...controller.attendeesInstitutional,
      ...controller.attendeesLocal,
    ]
        .where((a) => controller.selectedAttendeeIds.contains(a.id))
        .map((a) {
          final representative = controller.attendeeRepresentative(a.id);
          if (representative == null) return a.name;
          return '${a.name} ($representative)';
        })
        .toList();
    final attendeesText = attendeesList.isEmpty
        ? 'Ninguno'
        : attendeesList.length <= 3
            ? attendeesList.join(', ')
            : '${attendeesList.length} asistentes seleccionados';

    final hasEvidence = controller.hasEvidence;
    final evidenceText = hasEvidence 
        ? '${controller.evidencias.length} foto${controller.evidencias.length > 1 ? 's' : ''}'
        : 'Sin evidencia';

    final reportNotes = controller.getReportNotes();
    final reportAgreements = controller.getReportAgreements();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirmar registro',
            style: SaoTypography.pageTitle,
          ),
          const SizedBox(height: 10),

          // Información de la actividad (no editable)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Proyecto: ${controller.projectCode}', style: const TextStyle(color: SaoColors.gray500)),
                Text('Frente: ${a.frente}', style: const TextStyle(color: SaoColors.gray500)),
                Text('Ubicación: ${a.municipio}, ${a.estado}', style: const TextStyle(color: SaoColors.gray500)),
              ],
            ),
          ),

          // Actividad no planeada (editable - paso 0)
          if (controller.isUnplanned) ...[
            const SizedBox(height: 12),
            _editableCard(
              context: context,
              title: 'No planeada',
              onEdit: () => onJumpToStep(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Motivo', controller.unplannedReasonLabel),
                  if (controller.unplannedReference.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow('Referencia', controller.unplannedReference.trim()),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Contexto (editable - paso 0)
          _editableCard(
            context: context,
            title: 'Contexto',
            onEdit: () => onJumpToStep(0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: riskColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Riesgo: $riskText', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Clasificación (editable - paso 1)
          _editableCard(
            context: context,
            title: 'Clasificación',
            onEdit: () => onJumpToStep(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Subcategoría', sub),
                const SizedBox(height: 4),
                _infoRow('Propósito', pur),
                const SizedBox(height: 4),
                _infoRow('Resultado', res),
                const Divider(height: 16),
                _infoRow('Temas', topicsText),
                const SizedBox(height: 4),
                _infoRow('Asistentes', attendeesText),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Evidencia (editable - paso 2)
          _editableCard(
            context: context,
            title: 'Evidencia',
            onEdit: () => onJumpToStep(2),
            child: Row(
              children: [
                Icon(
                  hasEvidence ? Icons.check_circle : Icons.info_outline,
                  size: 18,
                  color: hasEvidence ? SaoColors.success : SaoColors.gray500,
                ),
                const SizedBox(width: 8),
                Text(evidenceText, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          if (reportNotes.isNotEmpty || reportAgreements.isNotEmpty) ...[
            const SizedBox(height: 12),
            _editableCard(
              context: context,
              title: 'Minuta / Reporte',
              onEdit: () => onJumpToStep(1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reportNotes.isNotEmpty) ...[
                    _infoRow('Desarrollo / Notas', reportNotes),
                  ],
                  if (reportAgreements.isNotEmpty) ...[
                    if (reportNotes.isNotEmpty) const SizedBox(height: 8),
                    Text(
                      'Acuerdos / Pendientes:',
                      style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
                    ),
                    const SizedBox(height: 4),
                    ...reportAgreements.map(
                      (agreement) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• $agreement',
                          style: SaoTypography.bodyText.copyWith(color: SaoColors.primary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onBack,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: controller.canSave
                      ? () => _handleSave(context, hasEvidence)
                      : null,
                  child: Text(
                    controller.isUnplanned ? 'Enviar a revisión' : 'Guardar',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
        ),
        Expanded(
          child: Text(
            value,
            style: SaoTypography.bodyText.copyWith(color: SaoColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: SaoColors.gray900.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _editableCard({
    required BuildContext context,
    required String title,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: SaoColors.gray900.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: SaoTypography.cardTitle.copyWith(
                          fontWeight: FontWeight.w900,
                          color: SaoColors.primary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: SaoColors.gray500,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(BuildContext context, bool hasEvidence) async {
    // Validación Gatekeeper antes de guardar
    final gk = controller.validateBeforeSave();

    if (!gk.isValid) {
      if (gk.errorFieldKey == 'btn_agregar_foto') {
        final savePending = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: SaoColors.warning),
                SizedBox(width: 8),
                Text('Guardar como pendiente'),
              ],
            ),
            content: const Text(
              'La evidencia es obligatoria, pero puedes guardar esta actividad como pendiente '
              'y completar las fotos después.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Volver a evidencia'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Guardar pendiente'),
              ),
            ],
          ),
        );

        if (savePending == true) {
          await _persistActivity(context, hasEvidence: false, allowPendingWithoutEvidence: true);
          return;
        }
      }

      // Vibración para indicar error
      HapticFeedback.heavyImpact();
      
      // Mostrar diálogo con error
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: SaoColors.error),
              SizedBox(width: 8),
              Text('Validación incompleta'),
            ],
          ),
          content: Text(gk.errorMessage ?? 'Completa todos los campos requeridos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      
      // Saltar al paso con error
      if (gk.step != null) {
        onJumpToStep(gk.step!);
        // TODO: Scroll to gk.errorFieldKey if needed
      }
      
      return;
    }

    await _persistActivity(context, hasEvidence: hasEvidence);
  }

  Future<void> _persistActivity(
    BuildContext context, {
    required bool hasEvidence,
    bool allowPendingWithoutEvidence = false,
  }) async {
    // Mostrar loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Guardando actividad...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final activityId = await controller.saveToDatabase(
        allowPendingWithoutEvidence: allowPendingWithoutEvidence,
      );

      if (!context.mounted) return;

      // Cerrar loading
      Navigator.of(context).pop();

      // Mostrar éxito
      final closeText = controller.isUnplanned
          ? 'Enviada a revisión pendiente'
          : allowPendingWithoutEvidence
            ? 'Guardada en pendiente para completar evidencia'
          : hasEvidence
              ? 'Terminada (con evidencia)'
              : 'Terminada (sin evidencia)';
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'Actividad guardada — $closeText',
          backgroundColor: SaoColors.success,
        ),
      );

      // Cerrar wizard
      Navigator.of(context).pop(activityId);
      
    } catch (e) {
      if (!context.mounted) return;

      // Cerrar loading
      Navigator.of(context).pop();

      // Mostrar error
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'Error al guardar: $e',
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }
}