// lib/features/operations/widgets/flag_resolution_dialog.dart
//
// Dialog for reviewing and resolving activity quality flags.
// Uses PATCH /api/v1/activities/{uuid}/flags to set/clear flags.
//
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/repositories/backend_api_client.dart';

/// Shows the [FlagResolutionDialog] for the given [activity].
/// Returns `true` if flags were modified (caller should refresh).
Future<bool> showFlagResolutionDialog(
  BuildContext context, {
  required ActivityWithDetails activity,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => FlagResolutionDialog(activity: activity),
  );
  return result ?? false;
}

/// Dialog that shows the current review flags (gpsMismatch, catalogChanged)
/// and allows the coordinator to clear them after manual review.
class FlagResolutionDialog extends StatefulWidget {
  final ActivityWithDetails activity;

  const FlagResolutionDialog({super.key, required this.activity});

  @override
  State<FlagResolutionDialog> createState() => _FlagResolutionDialogState();
}

class _FlagResolutionDialogState extends State<FlagResolutionDialog> {
  late bool _gpsMismatch;
  late bool _catalogChanged;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gpsMismatch = widget.activity.flags.gpsMismatch;
    _catalogChanged = widget.activity.flags.catalogChanged;
  }

  bool get _hasChanges =>
      _gpsMismatch != widget.activity.flags.gpsMismatch ||
      _catalogChanged != widget.activity.flags.catalogChanged;

  @override
  Widget build(BuildContext context) {
    final uuid = widget.activity.activity.id;
    final title = widget.activity.activity.title.isNotEmpty
        ? widget.activity.activity.title
        : uuid;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.flag_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 8),
          const Text('Flags de revisión'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Activity reference
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.railway_alert,
                      size: 16, color: AppColors.gray500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Revisa cada flag y desmárcalo una vez que hayas verificado el problema.',
              style: TextStyle(color: AppColors.gray500, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // GPS Mismatch flag
            _FlagCard(
              icon: Icons.gps_not_fixed_rounded,
              iconColor: AppColors.error,
              title: 'Desajuste de GPS',
              description:
                  'La ubicación registrada por el operativo no coincide con el '
                  'punto kilométrico declarado (diferencia > 50 m). '
                  'Verifica la evidencia fotográfica y el PK capturado.',
              value: _gpsMismatch,
              onChanged: (v) => setState(() => _gpsMismatch = v),
            ),
            const SizedBox(height: 12),

            // Catalog Changed flag
            _FlagCard(
              icon: Icons.swap_horiz_rounded,
              iconColor: AppColors.warning,
              title: 'Tipo de actividad modificado',
              description:
                  'La actividad fue creada con un tipo de catálogo que ya no existe '
                  'en la versión actual. Verifica que el tipo registrado sea '
                  'válido o solicita corrección al operativo.',
              value: _catalogChanged,
              onChanged: (v) => setState(() => _catalogChanged = v),
            ),

            // Error feedback
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (!_hasChanges || _isSaving) ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 16),
          label: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final uuid = widget.activity.activity.id;
      await const BackendApiClient().patchJson(
        '/api/v1/activities/$uuid/flags',
        {
          'gps_mismatch': _gpsMismatch,
          'catalog_changed': _catalogChanged,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Error al guardar: $e';
        });
      }
    }
  }
}

// ─────────────────────────────────────────────
// Flag card widget
// ─────────────────────────────────────────────

class _FlagCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlagCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: value
            ? iconColor.withOpacity(0.06)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? iconColor.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        secondary: Icon(icon, color: value ? iconColor : AppColors.gray400),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: value ? iconColor : AppColors.gray700,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.gray500,
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: iconColor,
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}
