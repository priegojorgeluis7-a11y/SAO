// lib/ui/widgets/sao_validation_search_bar.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_typography.dart';

/// Barra de búsqueda inteligente para validación de operaciones
/// 
/// Características:
/// - Búsqueda en tiempo real (PK, actividad, ubicación)
/// - Sugerencias mientras escribe
/// - Atajos de teclado (Ctrl+K para enfocar)
/// - Indicador de resultados filtrados
class SaoValidationSearchBar extends StatefulWidget {
  const SaoValidationSearchBar({
    super.key,
    required this.onSearchChanged,
    this.onFilterPressed,
    this.resultCount,
    this.projectName,
    this.projectOptions,
    this.onProjectChanged,
    this.allProjectsLabel = 'Todos',
  });

  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onFilterPressed;
  final int? resultCount;
  final String? projectName;
  final List<String>? projectOptions;
  final ValueChanged<String>? onProjectChanged;
  final String allProjectsLabel;

  @override
  State<SaoValidationSearchBar> createState() => _SaoValidationSearchBarState();
}

class _SaoValidationSearchBarState extends State<SaoValidationSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasProjectSelector = widget.projectName != null;
    final canChangeProject =
      widget.projectOptions != null && widget.onProjectChanged != null;
    final effectiveProjectName =
      (widget.projectName ?? '').trim().isEmpty ? widget.allProjectsLabel : widget.projectName!.trim();
    final borderColor = _hasFocus ? SaoColors.primary : SaoColors.borderFor(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border.all(
          color: borderColor,
          width: _hasFocus ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(SaoRadii.full),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: SaoColors.primary.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Selector de proyecto (opcional)
          if (hasProjectSelector) ...[
            Padding(
              padding: const EdgeInsets.only(left: SaoSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SaoSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SaoColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_rounded,
                          size: 16,
                          color: SaoColors.primary,
                        ),
                        const SizedBox(width: 6),
                        if (canChangeProject)
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: (widget.projectName ?? '').trim(),
                              isDense: true,
                              borderRadius: BorderRadius.circular(SaoRadii.md),
                              icon: Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                                color: SaoColors.primary,
                              ),
                              style: SaoTypography.caption.copyWith(
                                color: SaoColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: '',
                                  child: Text(widget.allProjectsLabel),
                                ),
                                ...widget.projectOptions!.map(
                                  (projectId) => DropdownMenuItem<String>(
                                    value: projectId,
                                    child: Text(projectId),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                widget.onProjectChanged!(value);
                              },
                            ),
                          )
                        else
                          Text(
                            effectiveProjectName,
                            style: SaoTypography.caption.copyWith(
                              color: SaoColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 24,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: SaoSpacing.sm),
                    color: SaoColors.borderFor(context),
                  ),
                ],
              ),
            ),
          ],

          // Icono de búsqueda
          Padding(
            padding: EdgeInsets.only(
              left: hasProjectSelector ? 0 : SaoSpacing.md,
            ),
            child: Icon(
              Icons.search_rounded,
              color: _hasFocus ? SaoColors.primary : SaoColors.gray400,
              size: 20,
            ),
          ),

          const SizedBox(width: SaoSpacing.sm),

          // Campo de texto
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: SaoTypography.bodyText,
              decoration: InputDecoration(
                hintText: 'Buscar PK, actividad, ubicación...',
                hintStyle: SaoTypography.bodyText.copyWith(
                  color: SaoColors.gray400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: widget.onSearchChanged,
            ),
          ),

          // Indicador de resultados
          if (widget.resultCount != null && _controller.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: SaoColors.gray100,
                borderRadius: BorderRadius.circular(SaoRadii.sm),
              ),
              child: Text(
                '${widget.resultCount} resultado${widget.resultCount != 1 ? 's' : ''}',
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.gray600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: SaoSpacing.sm),
          ],

          // Botón limpiar
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: SaoColors.gray400,
              onPressed: _clear,
              tooltip: 'Limpiar búsqueda',
            )
          else if (widget.onFilterPressed != null)
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 18),
              color: SaoColors.gray400,
              onPressed: widget.onFilterPressed,
              tooltip: 'Filtros avanzados',
            ),

          const SizedBox(width: SaoSpacing.xs),
        ],
      ),
    );
  }
}
