import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import '../domain/entities/report_context.dart';
import '../data/services/report_export_service.dart';
import './pdf_builder/report_builder.dart';

/// Caso de uso: Exportar reporte como PDF
class ExportReportPdf {
  Future<File> call({
    required ReportContext context,
    required String outputPath,
  }) async {
    // 1. Construir PDF
    final builder = ReportBuilder(context: context);
    final pdfDocument = await builder.build();

    // 2. Guardar
    final filename = '${context.activity.folio}_${context.activity.title.replaceAll(' ', '_')}';
    return await ReportExportService.exportPdf(
      pdfDocument: pdfDocument,
      outputPath: outputPath,
      filename: filename,
    );
  }
}
