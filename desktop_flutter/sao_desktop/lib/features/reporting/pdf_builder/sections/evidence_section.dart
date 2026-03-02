import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:io';
import '../../domain/entities/report_context.dart';
import 'report_section.dart';

/// Sección 8: Evidences (fotos con pies editables)
class EvidenceSection extends ReportSection {
  EvidenceSection({required super.context});

  @override
  Future<List<pw.Widget>> build() async {
    final widgets = <pw.Widget>[];
    const mainColor = PdfColor.fromInt(0xFF0B231E);

    if (context.imageEvidences.isEmpty) {
      widgets.add(
        pw.Text(
          'Sin evidencias disponibles',
          style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF9CA3AF)),
        ),
      );
      return widgets;
    }

    // Título de sección
    widgets.add(
      pw.Text(
        'SECCIÓN 8. EVIDENCIAS',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: mainColor,
        ),
      ),
    );

    widgets.add(pw.SizedBox(height: 8));

    // Procesar imágenes
    for (int i = 0; i < context.imageEvidences.length; i++) {
      final evidence = context.imageEvidences[i];
      
      try {
        // Intentar cargar la imagen
        final imageFile = File(evidence.filePath);
        if (!await imageFile.exists()) {
          widgets.add(
            pw.Text(
              'Figura ${i + 1}: Imagen no disponible (${evidence.caption ?? 'sin pie'})',
              style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF6B7280)),
            ),
          );
          continue;
        }

        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        // Título de figura
        widgets.add(
          pw.Text(
            'Figura ${i + 1}: ${evidence.caption ?? '(Sin pie de foto)'}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: mainColor,
            ),
          ),
        );

        // Imagen con altura máxima
        widgets.add(
          pw.Image(
            image,
            width: 400,
            height: 300,
            fit: pw.BoxFit.cover,
          ),
        );

        // Metadatos
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(evidence.capturedAt);
        widgets.add(
          pw.Text(
            'Fecha: $dateStr',
            style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF6B7280)),
          ),
        );

        if (evidence.latitude != null && evidence.longitude != null) {
          widgets.add(
            pw.Text(
              'GPS: ${evidence.latitude!.toStringAsFixed(4)}, ${evidence.longitude!.toStringAsFixed(4)}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF6B7280)),
            ),
          );
        }

        widgets.add(pw.SizedBox(height: 10));
      } catch (e) {
        widgets.add(
          pw.Text(
            'Error al cargar imagen: ${evidence.caption ?? evidence.filePath}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFDC2626)),
          ),
        );
        widgets.add(pw.SizedBox(height: 5));
      }
    }

    // Listado de PDFs anexos
    if (context.pdfEvidences.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 15));
      widgets.add(
        pw.Text(
          'ANEXOS (Documentos)',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: mainColor,
          ),
        ),
      );

      final pdfData = context.pdfEvidences.map((pdf) {
        final fileName = pdf.filePath.split('/').last;
        final size = pdf.fileSizeBytes != null 
            ? '${(pdf.fileSizeBytes! / 1024).toStringAsFixed(1)} KB'
            : 'N/A';
        return [
          'Anexo ${context.pdfEvidences.indexOf(pdf) + 1}',
          fileName,
          size,
          pdf.caption ?? 'Sin descripción',
        ];
      }).toList();

      pdfData.insert(0, ['Nº', 'Nombre Archivo', 'Tamaño', 'Descripción']);

      // Build table rows
      final rows = <pw.TableRow>[
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: mainColor),
          children: pdfData[0].cast<String>().map((header) => pw.Padding(
            padding: pw.EdgeInsets.all(4),
            child: pw.Text(header, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          )).toList(),
        ),
      ];

      // Add data rows
      for (final row in pdfData.skip(1)) {
        rows.add(
          pw.TableRow(
            children: row.cast<String>().map((cell) => pw.Padding(
              padding: pw.EdgeInsets.all(4),
              child: pw.Text(cell, style: const pw.TextStyle(fontSize: 7)),
            )).toList(),
          ),
        );
      }

      widgets.add(
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            top: pw.BorderSide(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            bottom: pw.BorderSide(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            left: pw.BorderSide(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
            right: pw.BorderSide(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
          ),
          children: rows,
        ),
      );
    }

    return widgets;
  }
}
