import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../domain/entities/report_context.dart';
import 'report_section.dart';

/// Sección: Encabezado institucional
class HeaderSection extends ReportSection {
  HeaderSection({required super.context});

  @override
  Future<List<pw.Widget>> build() async {
    final widgets = <pw.Widget>[];

    // Color institucional
    const mainColor = PdfColor.fromInt(0xFF0B231E); // verde oscuro
    const accentColor = PdfColor.fromInt(0xFFB38E5D); // dorado

    // Título: Folio
    widgets.add(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'FOLIO: ${context.activity.folio}',
            style: pw.TextStyle(
              fontSize: 10,
              color: mainColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          // Proyecto
          pw.Text(
            'Proyecto: ${context.activity.projectName ?? context.activity.projectCode}',
            style: pw.TextStyle(
              fontSize: 10,
              color: const PdfColor.fromInt(0xFF4B5563),
            ),
          ),
          // Frente
          if (context.activity.frontName != null)
            pw.Text(
              'Frente: ${context.activity.frontName}',
              style: pw.TextStyle(
                fontSize: 10,
                color: const PdfColor.fromInt(0xFF4B5563),
              ),
            ),
        ],
      ),
    );

    widgets.add(pw.SizedBox(height: 10));

    // Título principal
    widgets.add(
      pw.Text(
        context.activity.typeLabel.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: mainColor,
        ),
      ),
    );

    widgets.add(pw.Divider(color: accentColor, thickness: 2));

    // Datos principales
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(context.activity.executedAt);
    
    widgets.add(
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Fecha:',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                dateStr,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Título:',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(
                width: 300,
                child: pw.Text(
                  context.activity.title,
                  style: const pw.TextStyle(fontSize: 9),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Marca de agua si no está validado
    if (context.activity.watermark.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 15));
      widgets.add(
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFDC2626), width: 2),
            color: const PdfColor.fromInt(0xFFFEE2E2),
          ),
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            context.activity.watermark,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFFDC2626),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
