// lib/features/operations/widgets/caption_editor_widget.dart
import 'package:flutter/material.dart';
import '../../../ui/sao_ui.dart';

class CaptionEditorWidget extends StatefulWidget {
  const CaptionEditorWidget({
    super.key,
    required this.initialCaption,
    required this.evidenceId,
    this.onSaveCaption,
    this.onCancel,
    this.maxLines = 3,
  });

  final String initialCaption;
  final String evidenceId;
  final Function(String caption)? onSaveCaption;
  final VoidCallback? onCancel;
  final int maxLines;

  @override
  State<CaptionEditorWidget> createState() => _CaptionEditorWidgetState();
}

class _CaptionEditorWidgetState extends State<CaptionEditorWidget> {
  late TextEditingController _controller;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCaption() async {
    if (_controller.text.trim() == widget.initialCaption) {
      // Sin cambios
      _cancelEdit();
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Simular delay de guardado
      await Future.delayed(const Duration(milliseconds: 500));
      
      widget.onSaveCaption?.call(_controller.text.trim());
      
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: SaoColors.onPrimary, size: 18),
                SizedBox(width: SaoSpacing.sm),
                Text('Pie de foto actualizado'),
              ],
            ),
            backgroundColor: SaoColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SaoRadii.sm),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SaoColors.error,
          ),
        );
      }
    }
  }

  void _cancelEdit() {
    _controller.text = widget.initialCaption;
    setState(() => _isEditing = false);
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(SaoRadii.lg),
        border: Border.all(
          color: _isEditing ? SaoColors.primary : SaoColors.border,
          width: _isEditing ? 2 : 1,
        ),
        boxShadow: [
          if (_isEditing)
            BoxShadow(
              color: SaoColors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.all(SaoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pie de Foto',
                style: SaoTypography.sectionTitle,
              ),
              if (!_isEditing)
                Tooltip(
                  message: 'Editar pie de foto',
                  child: Material(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                    child: InkWell(
                      onTap: () => setState(() => _isEditing = true),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      child: const Padding(
                        padding: EdgeInsets.all(SaoSpacing.xs),
                        child: Icon(
                          Icons.edit_rounded,
                          color: SaoColors.gray600,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

            const SizedBox(height: SaoSpacing.sm),

          // Content
          if (_isEditing)
            Column(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: widget.maxLines,
                  decoration: InputDecoration(
                    hintText: 'Describe lo que ves en esta imagen...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                      borderSide: const BorderSide(
                        color: SaoColors.border,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                      borderSide: const BorderSide(
                        color: SaoColors.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                      borderSide: const BorderSide(
                        color: SaoColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(SaoSpacing.sm),
                    filled: true,
                    fillColor: SaoColors.gray50,
                  ),
                  style: SaoTypography.bodyText,
                ),
                const SizedBox(height: SaoSpacing.sm),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : _cancelEdit,
                      style: TextButton.styleFrom(
                        foregroundColor: SaoColors.gray600,
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: SaoSpacing.sm),
                    FilledButton(
                      onPressed: _isSaving ? null : _saveCaption,
                      style: FilledButton.styleFrom(
                        backgroundColor: SaoColors.primary,
                      ),
                      child: _isSaving
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      SaoColors.onPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(width: SaoSpacing.xs),
                                Text('Guardando...'),
                              ],
                            )
                          : const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SaoSpacing.sm),
              decoration: BoxDecoration(
                color: SaoColors.gray50,
                borderRadius: BorderRadius.circular(SaoRadii.sm),
              ),
              child: _controller.text.isEmpty
                  ? Text(
                      'Sin descripción',
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.gray500,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Text(
                      _controller.text,
                      style: SaoTypography.bodyText.copyWith(
                        color: SaoColors.gray800,
                        height: 1.4,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Version simple inline para usar en galería de evidencias
class InlineCaptionEditor extends StatefulWidget {
  const InlineCaptionEditor({
    super.key,
    required this.caption,
    required this.onSave,
  });

  final String caption;
  final Function(String) onSave;

  @override
  State<InlineCaptionEditor> createState() => _InlineCaptionEditorState();
}

class _InlineCaptionEditorState extends State<InlineCaptionEditor> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.caption);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing && _controller.text != widget.caption) {
      widget.onSave(_controller.text);
    }
    if (!_isEditing) {
      setState(() => _isEditing = true);
    } else {
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return SizedBox(
        height: 80,
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          decoration: InputDecoration(
            hintText: 'Descripción de la imagen...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SaoRadii.sm),
              borderSide: const BorderSide(
                color: SaoColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(SaoSpacing.sm),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            suffixIcon: Padding(
              padding: const EdgeInsets.all(SaoSpacing.xs),
              child: IconButton(
                icon: const Icon(
                  Icons.check_rounded,
                  color: SaoColors.success,
                  size: 20,
                ),
                onPressed: _toggleEdit,
              ),
            ),
          ),
          style: SaoTypography.caption,
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleEdit,
      child: Container(
        padding: const EdgeInsets.all(SaoSpacing.sm),
        decoration: BoxDecoration(
          color: SaoColors.gray50,
          borderRadius: BorderRadius.circular(SaoRadii.sm),
          border: Border.all(color: SaoColors.border),
        ),
        child: widget.caption.isEmpty
            ? Text(
                'Haz clic para agregar descripción',
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.gray500,
                  fontStyle: FontStyle.italic,
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.caption,
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.gray700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: SaoSpacing.xs),
                  const Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: SaoColors.gray600,
                  ),
                ],
              ),
      ),
    );
  }
}
