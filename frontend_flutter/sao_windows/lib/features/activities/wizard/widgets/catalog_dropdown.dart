// lib/features/activities/wizard/widgets/catalog_dropdown.dart
import 'package:flutter/material.dart';
import '../../../../ui/theme/sao_typography.dart';

/// Dropdown genérico para catálogos con modelo CatalogItem.
///
/// Usa un [DropdownButtonFormField<T>] tipado para los items del catálogo.
/// El botón "Agregar nuevo..." se muestra como un widget separado debajo
/// del dropdown para evitar mezclar tipos y problemas de estado interno.
class CatalogDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final VoidCallback? onAddNew;

  const CatalogDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay items, mostrar botón para agregar
    if (items.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onAddNew,
        icon: const Icon(Icons.add),
        label: Text('Agregar $label'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
    }

    // Asegurar que el valor actual existe en la lista de items
    final effectiveValue =
        (value != null && items.contains(value)) ? value : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<T>(
          // Key basada en número de items + valor seleccionado para forzar
          // reconstrucción cuando se agregan items custom al catálogo.
          key: ValueKey('${label}_${items.length}_${effectiveValue.hashCode}'),
          value: effectiveValue,
          isExpanded: true,
          menuMaxHeight: MediaQuery.of(context).size.height * 0.5,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: const Icon(Icons.arrow_drop_down, size: 24),
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: items
              .map(
                (x) => DropdownMenuItem<T>(
                  value: x,
                  child: Text(
                    itemLabel(x),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: SaoTypography.bodyText,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
        if (onAddNew != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAddNew,
              icon: Icon(Icons.add_circle_outline,
                  size: 18, color: Theme.of(context).primaryColor),
              label: Text(
                'Agregar nuevo...',
                style: SaoTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}
