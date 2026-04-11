import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'report_section.dart';

/// Sección 2: Datos Generales (tabla técnica)
class GeneralDataSection extends ReportSection {
  GeneralDataSection({required super.context});

  @override
  Future<List<pw.Widget>> build() async {
    final widgets = <pw.Widget>[];
    const mainColor = PdfColor.fromInt(0xFF0B231E);
    const borderColor = PdfColor.fromInt(0xFFE5E7EB);

    // Título de sección
    widgets.add(
      pw.Text(
        'SECCIÓN 1. DATOS GENERALES',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: mainColor,
        ),
      ),
    );

    widgets.add(pw.SizedBox(height: 8));

    // Tabla de datos
    final data = [
      ['Campo', 'Valor'],
      ['Tipo de Actividad', context.activity.typeLabel],
      ['Proyecto', context.activity.projectName ?? context.activity.projectCode],
      ['Frente', context.activity.frontName ?? 'N/A'],
      ['PK Declarado', context.activity.pkDeclared ?? 'N/A'],
      ['Fecha Ejecución', DateFormat('dd/MM/yyyy HH:mm').format(context.activity.executedAt)],
      ['Estado', context.activity.status.toUpperCase()],
      if (context.activity.latitude != null)
        ['GPS Latitud', context.activity.latitude!.toStringAsFixed(6)],
      if (context.activity.longitude != null)
        ['GPS Longitud', context.activity.longitude!.toStringAsFixed(6)],
      if (context.activity.gpsDistanceToPk != null)
        ['Distancia GPS-PK', '${context.activity.gpsDistanceToPk!.toStringAsFixed(1)} m'],
      ['Riesgo Clasificado', context.activity.riskClassification.displayLabel],
      ['Etiquetas', context.activity.riskClassification.tags.join(', ')],
      if (context.activity.validatedAt != null)
        ['Fecha Validación', DateFormat('dd/MM/yyyy').format(context.activity.validatedAt!)],
      if (context.activity.validatedBy != null)
        ['Validado por', context.activity.validatedBy!],
      ['Total Evidencias', '${context.totalEvidences}'],
      ['Acuerdos Registrados', '${context.agreements.length}'],
      ['Participantes', '${context.attendees.length}'],
    ];

    // Build rows
    final rows = <pw.TableRow>[
      // Header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: mainColor,
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Campo', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text('Valor', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
        ],
      ),
    ];

    // Add data rows
    for (final row in data) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
                child: pw.Text(row[0], style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      );
    }

    widgets.add(
      pw.Table(
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
          top: pw.BorderSide(color: borderColor, width: 0.5),
          bottom: pw.BorderSide(color: borderColor, width: 0.5),
          left: pw.BorderSide(color: borderColor, width: 0.5),
          right: pw.BorderSide(color: borderColor, width: 0.5),
        ),
        children: rows,
      ),
    );

    return widgets;
  }
}
