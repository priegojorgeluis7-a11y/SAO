import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';

/// Modal: Gestión Inteligente del Catálogo
/// 
/// Permite:
/// - Buscar opciones del catálogo
/// - Ver diferencias con valor actual
/// - Sustituir con propuesta del catálogo
/// - Registrar decisión en auditoría
class CatalogSubstitutionModal extends StatefulWidget {
  final String currentValue;
  final String fieldName;
  final List<CatalogItem> items;
  final Function(String selectedValue) onSubstitute;

  const CatalogSubstitutionModal({
    super.key,
    required this.currentValue,
    required this.fieldName,
    required this.items,
    required this.onSubstitute,
  });

  @override
  State<CatalogSubstitutionModal> createState() => _CatalogSubstitutionModalState();
}

class _CatalogSubstitutionModalState extends State<CatalogSubstitutionModal> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedValue = '';

  List<CatalogItem> get _filteredItems {
    final all = widget.items;
    if (_searchController.text.isEmpty) return all;
    final query = _searchController.text.toLowerCase();
    return all
        .where((item) =>
            item.name.toLowerCase().contains(query) ||
            item.code.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.currentValue;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(SaoRadii.lg),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(SaoSpacing.lg),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: SaoColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: SaoColors.primary),
                      SizedBox(width: SaoSpacing.sm),
                      Expanded(
                        child: Text(
                          'Sustituir por Catálogo',
                          style: SaoTypography.sectionTitle,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.md),
                  Text(
                    'Campo: ${widget.fieldName}',
                    style: SaoTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SaoColors.gray600,
                    ),
                  ),
                  SizedBox(height: SaoSpacing.sm),
                  Container(
                    padding: EdgeInsets.all(SaoSpacing.sm),
                    decoration: BoxDecoration(
                      color: SaoColors.gray50,
                      border: Border.all(color: SaoColors.border),
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                    ),
                    child: Text(
                      'Valor actual: "${widget.currentValue}"',
                      style: SaoTypography.bodyText.copyWith(
                        color: SaoColors.gray700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Busqueda
            Container(
              padding: EdgeInsets.all(SaoSpacing.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: SaoColors.border)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, código o categoría...',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SaoRadii.md),
                    borderSide: BorderSide(color: SaoColors.border),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: SaoSpacing.md,
                    vertical: SaoSpacing.sm,
                  ),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),

            // Lista de catálogo
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'Sin coincidencias',
                        style: SaoTypography.bodyText
                            .copyWith(color: SaoColors.gray500),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(SaoSpacing.md),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = _selectedValue == item.name;

                        return _buildCatalogItemTile(item, isSelected);
                      },
                    ),
            ),

            // Footer con acciones
            Container(
              padding: EdgeInsets.all(SaoSpacing.lg),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: SaoColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: SaoSpacing.md),
                  ElevatedButton.icon(
                    onPressed: _selectedValue.isEmpty
                        ? null
                        : () {
                            widget.onSubstitute(_selectedValue);
                            Navigator.pop(context);
                          },
                    icon: Icon(Icons.check_rounded),
                    label: Text('Elegir: "${_selectedValue.length > 30 ? _selectedValue.substring(0, 30) + "..." : _selectedValue}"'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaoColors.primary,
                      foregroundColor: SaoColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogItemTile(CatalogItem item, bool isSelected) {
    return Container(
      margin: EdgeInsets.only(bottom: SaoSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? SaoColors.primary : SaoColors.border,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(SaoRadii.md),
        color: isSelected
            ? SaoColors.primary.withOpacity(0.05)
            : SaoColors.surface,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedValue = item.name),
        borderRadius: BorderRadius.circular(SaoRadii.md),
        child: Padding(
          padding: EdgeInsets.all(SaoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: SaoTypography.bodyTextBold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.isRecommended)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: SaoSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: SaoColors.success.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(SaoRadii.sm),
                                  border: Border.all(
                                    color: SaoColors.success,
                                  ),
                                ),
                                child: Text(
                                  'Recomendado',
                                  style: SaoTypography.caption.copyWith(
                                    color: SaoColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: SaoSpacing.xs),
                        Row(
                          children: [
                            Text(
                              item.code,
                              style: SaoTypography.mono.copyWith(
                                color: SaoColors.gray600,
                              ),
                            ),
                            SizedBox(width: SaoSpacing.md),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: SaoSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: SaoColors.info.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(SaoRadii.sm),
                              ),
                              child: Text(
                                item.category,
                                style: SaoTypography.caption.copyWith(
                                  color: SaoColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: SaoSpacing.md),
                  Radio(
                    value: item.name,
                    groupValue: _selectedValue,
                    activeColor: SaoColors.primary,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedValue = value);
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: SaoSpacing.sm),
              Text(
                item.description,
                style: SaoTypography.bodyText.copyWith(
                  color: SaoColors.gray600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.standards.isNotEmpty) ...[
                SizedBox(height: SaoSpacing.sm),
                Wrap(
                  spacing: SaoSpacing.xs,
                  children: item.standards
                      .map((std) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: SaoSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: SaoColors.gray100,
                              borderRadius: BorderRadius.circular(
                                SaoRadii.sm,
                              ),
                            ),
                            child: Text(
                              std,
                              style: SaoTypography.caption.copyWith(
                                color: SaoColors.gray700,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogItem {
  final String id;
  final String code;
  final String name;
  final String category;
  final String description;
  final List<String> standards;
  final bool isRecommended;

  CatalogItem({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.description,
    required this.standards,
    required this.isRecommended,
  });
}