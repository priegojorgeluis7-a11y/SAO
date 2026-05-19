import '../../../../core/compat/io_compat.dart';
import '../entities/report_context.dart';
import '../../data/services/report_export_service.dart';
import '../../pdf_builder/report_builder.dart';

/// Caso de uso: Exportar reporte completo (PDF + evidencias + manifest)
class ExportReportPackage {
  Future<Directory> call({
    required ReportContext context,
    required String outputPath,
  }) async {
    // 1. Construir PDF
    final builder = ReportBuilder(context: context);
    final pdfDocument = await builder.build();

    // 2. Guardar paquete
    return await ReportExportService.exportPackage(
      pdfDocument: pdfDocument,
      context: context,
      outputPath: outputPath,
    );
  }
}
