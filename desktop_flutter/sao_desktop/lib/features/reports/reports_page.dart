import 'package:flutter/material.dart';
import '../../ui/theme/sao_colors.dart';
import '../../ui/theme/sao_spacing.dart';
import '../../ui/theme/sao_typography.dart';
import '../../ui/theme/sao_radii.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? selectedProject = 'TMQ';
  String? selectedFront = 'Frente A';
  DateTimeRange? dateRange = DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 2, 18));

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Panel: Filters
        Expanded(
          flex: 1,
          child: Container(
            color: SaoColors.gray50,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(SaoSpacing.md),
                  color: SaoColors.surface,
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: SaoColors.primary),
                      SizedBox(width: SaoSpacing.sm),
                      Text('Reportes', style: SaoTypography.sectionTitle),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.all(SaoSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proyecto', style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray700)),
                      SizedBox(height: SaoSpacing.xs),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: SaoColors.border), borderRadius: BorderRadius.circular(SaoRadii.md)),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedProject,
                          underline: SizedBox(),
                          onChanged: (v) => setState(() => selectedProject = v),
                          items: ['TMQ', 'TAP', 'SNL'].map((p) => DropdownMenuItem(value: p, child: Padding(padding: EdgeInsets.symmetric(horizontal: SaoSpacing.sm), child: Text(p)))).toList(),
                        ),
                      ),
                      SizedBox(height: SaoSpacing.lg),
                      Text('Frente', style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray700)),
                      SizedBox(height: SaoSpacing.xs),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: SaoColors.border), borderRadius: BorderRadius.circular(SaoRadii.md)),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedFront,
                          underline: SizedBox(),
                          onChanged: (v) => setState(() => selectedFront = v),
                          items: ['Frente A', 'Frente B', 'Frente C'].map((f) => DropdownMenuItem(value: f, child: Padding(padding: EdgeInsets.symmetric(horizontal: SaoSpacing.sm), child: Text(f)))).toList(),
                        ),
                      ),
                      SizedBox(height: SaoSpacing.lg),
                      Text('Rango de Fechas', style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray700)),
                      SizedBox(height: SaoSpacing.sm),
                      if (dateRange != null)
                        Text('${dateRange!.start.day}/${dateRange!.start.month} - ${dateRange!.end.day}/${dateRange!.end.month}', style: SaoTypography.caption),
                      SizedBox(height: SaoSpacing.sm),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final range = await showDateRangePicker(context: context, firstDate: DateTime(2025), lastDate: DateTime(2027));
                          if (range != null) setState(() => dateRange = range);
                        },
                        icon: Icon(Icons.calendar_today_rounded),
                        label: Text('Seleccionar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Center Panel: Preview
        Expanded(
          flex: 2,
          child: Container(
            color: SaoColors.gray100,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(SaoSpacing.md),
                  color: SaoColors.surface,
                  child: Row(
                    children: [
                      Icon(Icons.preview_rounded, color: SaoColors.primary),
                      SizedBox(width: SaoSpacing.sm),
                      Text('Vista Previa', style: SaoTypography.sectionTitle),
                      Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vista previa generada'), duration: Duration(seconds: 2))),
                        icon: Icon(Icons.refresh_rounded),
                        label: Text('Generar'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 500,
                      margin: EdgeInsets.all(SaoSpacing.lg),
                      padding: EdgeInsets.all(SaoSpacing.lg),
                      decoration: BoxDecoration(
                        color: SaoColors.surface,
                        borderRadius: BorderRadius.circular(SaoRadii.lg),
                        boxShadow: [BoxShadow(color: SaoColors.gray900.withOpacity(0.1), blurRadius: 8)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(SaoSpacing.lg),
                            decoration: BoxDecoration(color: SaoColors.primary, borderRadius: BorderRadius.circular(SaoRadii.md)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('REPORTE SAO', style: SaoTypography.sectionTitle.copyWith(color: SaoColors.surface, fontSize: 18)),
                                SizedBox(height: SaoSpacing.sm),
                                Text('Reunión Comunitaria en San Ildefonso', style: SaoTypography.bodyText.copyWith(color: SaoColors.surface, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          SizedBox(height: SaoSpacing.lg),
                          _buildRow('Proyecto', 'Tramo 4 - Metepec Querétaro'),
                          _buildRow('Frente', 'Frente A'),
                          _buildRow('Fecha', '15/02/2026'),
                          _buildRow('Estado', 'APROBADO'),
                          _buildRow('PK', '142+500'),
                          _buildRow('Distancia GPS', '450m'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Panel: Options
        Expanded(
          flex: 1,
          child: Container(
            color: SaoColors.surface,
            padding: EdgeInsets.all(SaoSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_rounded, color: SaoColors.primary),
                      SizedBox(width: SaoSpacing.sm),
                      Text('Opciones', style: SaoTypography.sectionTitle.copyWith(fontSize: 16)),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.lg),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: SaoColors.border), borderRadius: BorderRadius.circular(SaoRadii.md)),
                    child: Column(
                      children: [
                        CheckboxListTile(value: true, onChanged: (_) {}, title: Text('Auditoría', style: SaoTypography.bodyText.copyWith(fontWeight: FontWeight.w600)), subtitle: Text('Timeline de cambios', style: SaoTypography.caption.copyWith(fontSize: 11)), contentPadding: EdgeInsets.all(SaoSpacing.sm), activeColor: SaoColors.primary),
                        Divider(height: 1, color: SaoColors.border),
                        CheckboxListTile(value: false, onChanged: (_) {}, title: Text('Notas Internas', style: SaoTypography.bodyText.copyWith(fontWeight: FontWeight.w600)), subtitle: Text('Solo revisión interna', style: SaoTypography.caption.copyWith(fontSize: 11)), contentPadding: EdgeInsets.all(SaoSpacing.sm), activeColor: SaoColors.primary),
                        Divider(height: 1, color: SaoColors.border),
                        CheckboxListTile(value: true, onChanged: (_) {}, title: Text('Anexos', style: SaoTypography.bodyText.copyWith(fontWeight: FontWeight.w600)), subtitle: Text('Fotos y documentos', style: SaoTypography.caption.copyWith(fontSize: 11)), contentPadding: EdgeInsets.all(SaoSpacing.sm), activeColor: SaoColors.primary),
                      ],
                    ),
                  ),
                  SizedBox(height: SaoSpacing.xxl),
                  Text('Resumen Ejecutivo', style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray700)),
                  SizedBox(height: SaoSpacing.sm),
                  TextField(
                    decoration: InputDecoration(hintText: 'Agregar resumen...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(SaoRadii.md)), contentPadding: EdgeInsets.all(SaoSpacing.sm)),
                    maxLines: 4,
                  ),
                  SizedBox(height: SaoSpacing.xxl),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📥 PDF descargado'), duration: Duration(seconds: 2))), icon: Icon(Icons.download_rounded), label: Text('Descargar PDF'), style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: SaoSpacing.md), backgroundColor: SaoColors.success))),
                  SizedBox(height: SaoSpacing.md),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📦 ZIP exportado'), duration: Duration(seconds: 2))), icon: Icon(Icons.archive_rounded), label: Text('Exportar ZIP'), style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: SaoSpacing.md), backgroundColor: SaoColors.info))),
                  SizedBox(height: SaoSpacing.md),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📧 Email enviado'), duration: Duration(seconds: 2))), icon: Icon(Icons.mail_rounded), label: Text('Enviar Email'), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: SaoSpacing.md)))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: SaoSpacing.md),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray600))),
          Expanded(child: Text(value, style: SaoTypography.caption.copyWith(color: SaoColors.gray800))),
        ],
      ),
    );
  }
}
