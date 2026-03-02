import 'package:pdf/widgets.dart' as pw;
import '../domain/entities/report_context.dart';
import './pdf_builder/report_builder.dart';

/// Caso de uso: Construir vista previa del reporte
class BuildReportPreview {
  Future<pw.Document> call({
    required ReportContext context,
  }) async {
    final builder = ReportBuilder(context: context);
    return await builder.build();
  }
}
