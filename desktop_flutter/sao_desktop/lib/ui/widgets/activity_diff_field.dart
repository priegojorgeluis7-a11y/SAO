// lib/ui/widgets/activity_diff_field.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_typography.dart';

/// Campo de texto con diff view para comparar valores de catálogo vs campo
/// 
/// Características:
/// - Muestra diferencias visualmente (tachado vs resaltado)
/// - Edición inline con hover
/// - Botones para aceptar/rechazar cambios
/// - Estados: sin cambio, modificado, editando
class ActivityDiffField extends StatefulWidget {
  const ActivityDiffField({
    super.key,
    required this.label,
    required this.catalogValue,
    required this.fieldValue,
    this.onAcceptChange,
    this.onRevertChange,
    this.onEdit,
    this.readOnly = false,
  });

  final String label;
  final String catalogValue;
  final String fieldValue;
  final VoidCallback? onAcceptChange;
  final VoidCallback? onRevertChange;
  final ValueChanged<String>? onEdit;
  final bool readOnly;

  @override
  State<ActivityDiffField> createState() => _ActivityDiffFieldState();
}

class _ActivityDiffFieldState extends State<ActivityDiffField> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.fieldValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges => widget.catalogValue != widget.fieldValue;

  void _startEditing() {
    setState(() => _isEditing = true);
  }

  void _saveEdit() {
    widget.onEdit?.call(_controller.text);
    setState(() => _isEditing = false);
  }

  void _cancelEdit() {
    _controller.text = widget.fieldValue;
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: EdgeInsets.only(bottom: SaoSpacing.xs),
          child: Text(
            widget.label,
            style: SaoTypography.caption.copyWith(
              color: SaoColors.gray600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Contenedor del campo
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(SaoSpacing.md),
            decoration: BoxDecoration(
              color: _isEditing
                  ? SaoColors.surface
                  : _hasChanges
                      ? SaoColors.info.withOpacity(0.05)
                      : SaoColors.gray50,
              border: Border.all(
                color: _isEditing
                    ? SaoColors.primary
                    : _hasChanges
                        ? SaoColors.info
                        : _isHovering
                            ? SaoColors.borderStrong
                            : SaoColors.border,
                width: _isEditing || _hasChanges ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(SaoRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Diff View (si hay cambios)
                if (_hasChanges && !_isEditing) ...[
                  // Valor original (catálogo)
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: SaoColors.gray500,
                      ),
                      SizedBox(width: SaoSpacing.xs),
                      Text(
                        'Catálogo: ',
                        style: SaoTypography.caption.copyWith(
                          color: SaoColors.gray500,
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.catalogValue,
                          style: SaoTypography.bodyText.copyWith(
                            color: SaoColors.gray500,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.xs),
                  
                  // Valor nuevo (campo)
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 14,
                        color: SaoColors.info,
                      ),
                      SizedBox(width: SaoSpacing.xs),
                      Text(
                        'Campo: ',
                        style: SaoTypography.caption.copyWith(
                          color: SaoColors.info,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.fieldValue,
                          style: SaoTypography.bodyText.copyWith(
                            color: SaoColors.info,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.sm),
                  
                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onAcceptChange,
                          icon: Icon(Icons.check_rounded, size: 14),
                          label: Text('Aceptar cambio'),
                        ),
                      ),
                      SizedBox(width: SaoSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onRevertChange,
                          icon: Icon(Icons.restore_rounded, size: 14),
                          label: Text('Restaurar original'),
                        ),
                      ),
                    ],
                  ),
                ]
                // Vista normal (sin cambios) o edición
                else if (_isEditing) ...[
                  // Modo edición
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          style: SaoTypography.bodyText,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            hintText: 'Ingresa un valor...',
                            hintStyle: SaoTypography.bodyText.copyWith(
                              color: SaoColors.gray400,
                            ),
                          ),
                          onSubmitted: (_) => _saveEdit(),
                        ),
                      ),
                      SizedBox(width: SaoSpacing.sm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IconButtonSmall(
                            icon: Icons.check_rounded,
                            color: SaoColors.success,
                            onPressed: _saveEdit,
                            tooltip: 'Guardar (Enter)',
                          ),
                          SizedBox(width: 4),
                          _IconButtonSmall(
                            icon: Icons.close_rounded,
                            color: SaoColors.gray600,
                            onPressed: _cancelEdit,
                            tooltip: 'Cancelar (Esc)',
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  // Vista normal (solo lectura con hover)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.fieldValue.isNotEmpty
                              ? widget.fieldValue
                              : widget.catalogValue,
                          style: SaoTypography.bodyText,
                        ),
                      ),
                      if (_isHovering &&
                          !widget.readOnly &&
                          widget.onEdit != null)
                        IconButton(
                          icon: Icon(Icons.edit_rounded, size: 16),
                          color: SaoColors.primary,
                          padding: EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: _startEditing,
                          tooltip: 'Editar valor',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón de ícono pequeño para edición inline
class _IconButtonSmall extends StatelessWidget {
  const _IconButtonSmall({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
