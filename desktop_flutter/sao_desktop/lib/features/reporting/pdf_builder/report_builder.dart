import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../reporting/domain/entities/report_context.dart';
import 'sections/header_section.dart';
import 'sections/general_data_section.dart';
import 'sections/evidence_section.dart';

/// Constructor principal de reportes PDF
class ReportBuilder {
  final ReportContext context;

  ReportBuilder({required this.context});

  /// Construye el documento PDF completo
  Future<pw.Document> build() async {
    final pdf = pw.Document();

    // Página 1: Encabezado + Datos Generales + Evidencias
    final headerSection = HeaderSection(context: context);
    final generalDataSection = GeneralDataSection(context: context);
    final evidenceSection = EvidenceSection(context: context);

    // Construir secciones
    final headerWidgets = await headerSection.build();
    final generalDataWidgets = await generalDataSection.build();
    final evidenceWidgets = await evidenceSection.build();

    // Agregar página principal
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (context) {
          return [
            ...headerWidgets,
            pw.SizedBox(height: 20),
            ...generalDataWidgets,
            pw.SizedBox(height: 20),
            ...evidenceWidgets,
          ];
        },
      ),
    );

    return pdf;
  }
}
