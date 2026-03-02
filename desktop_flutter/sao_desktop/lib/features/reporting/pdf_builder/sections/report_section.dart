import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/report_context.dart';

/// Clase base para todas las secciones del reporte
abstract class ReportSection {
  final ReportContext context;

  ReportSection({required this.context});

  /// Construye los widgets de esta sección
  Future<List<pw.Widget>> build();
}
