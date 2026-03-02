// lib/features/activities/wizard/widgets/catalog_dropdown.dart
import 'package:flutter/material.dart';

/// Dropdown genérico para catálogos con modelo CatalogItem
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

    // Crear lista de items del menú
    final menuItems = <DropdownMenuItem<dynamic>>[
      // Items normales del catálogo
      ...items.map((x) => DropdownMenuItem<T>(
        value: x,
        child: Text(
          itemLabel(x),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: const TextStyle(fontSize: 14),
        ),
      )),
      
      // Agregar opción "Agregar nuevo" al final si está habilitada
      if (onAddNew != null)
        DropdownMenuItem<dynamic>(
          value: '__add_new__',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'Agregar nuevo...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
    ];

    return DropdownButtonFormField<dynamic>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: MediaQuery.of(context).size.height * 0.5,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixIcon: const Icon(Icons.arrow_drop_down, size: 24),
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: menuItems,
      onChanged: (dynamic newValue) {
        if (newValue == '__add_new__') {
          // Usuario seleccionó "Agregar nuevo"
          onAddNew?.call();
        } else {
          // Usuario seleccionó un item normal
          onChanged(newValue as T?);
        }
      },
    );
  }
}
