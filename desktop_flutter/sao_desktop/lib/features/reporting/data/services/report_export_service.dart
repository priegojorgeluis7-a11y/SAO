import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import '../../domain/entities/report_context.dart';

/// Servicio de exportación de reportes PDF
class ReportExportService {
  /// Exporta el PDF a un archivo
  static Future<File> exportPdf({
    required pw.Document pdfDocument,
    required String outputPath,
    required String filename,
  }) async {
    try {
      // Crear directorio si no existe
      final directory = Directory(outputPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Guardar PDF
      final file = File('$outputPath/$filename.pdf');
      final bytes = await pdfDocument.save();
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      throw Exception('Error al exportar PDF: $e');
    }
  }

  /// Exporta un paquete completo (PDF + evidencias + manifest)
  static Future<Directory> exportPackage({
    required pw.Document pdfDocument,
    required ReportContext context,
    required String outputPath,
  }) async {
    try {
      // Crear directorio del paquete
      final folio = context.activity.folio;
      final packageDir = Directory('$outputPath/$folio');
      
      if (!await packageDir.exists()) {
        await packageDir.create(recursive: true);
      }

      // 1. Guardar PDF
      final pdfFile = File('${packageDir.path}/$folio.pdf');
      final bytes = await pdfDocument.save();
      await pdfFile.writeAsBytes(bytes);

      // 2. Copiar evidencias
      final evidencesDir = Directory('${packageDir.path}/evidencias');
      await evidencesDir.create(recursive: true);

      for (final evidence in context.evidences) {
        final sourceFile = File(evidence.filePath);
        if (await sourceFile.exists()) {
          // basename handles both Windows (\) and POSIX (/) separators.
          final fileName = p.basename(sourceFile.path);
          await sourceFile.copy('${evidencesDir.path}/$fileName');
        }
      }

      // 3. Crear manifest.json
      final manifest = {
        'folio': folio,
        'proyecto': context.activity.projectCode,
        'frente': context.activity.frontName,
        'fecha_generación': DateTime.now().toIso8601String(),
        'tipo': context.activity.typeLabel,
        'estado': context.activity.status,
        'total_evidencias': context.totalEvidences,
        'evidencias': context.evidences
            .map((e) => {
              'id': e.id,
              'archivo': p.basename(e.filePath),
              'tipo': e.fileType,
              'caption': e.caption,
            })
            .toList(),
      };

      final manifestFile = File('${packageDir.path}/manifest.json');
      await manifestFile.writeAsString(
        _prettifyJson(manifest),
      );

      return packageDir;
    } catch (e) {
      throw Exception('Error al exportar paquete: $e');
    }
  }

  static String _prettifyJson(Map<String, dynamic> json) {
    // Simplificado - en producción usar jsonEncode con indent
    return json.toString();
  }
}
