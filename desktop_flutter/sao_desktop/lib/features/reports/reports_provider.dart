import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/providers/project_providers.dart';
import '../../data/repositories/backend_api_client.dart';

// ---------------------------------------------------------------------------
// Date range helper
// ---------------------------------------------------------------------------

class ReportDateRange {
  final DateTime start;
  final DateTime end;

  const ReportDateRange({required this.start, required this.end});
}

// ---------------------------------------------------------------------------
// Filter State
// ---------------------------------------------------------------------------

class ReportFilters {
  final String projectId;
  final String frontName;
  final ReportDateRange dateRange;

  const ReportFilters({
    required this.projectId,
    required this.frontName,
    required this.dateRange,
  });

  ReportFilters copyWith({
    String? projectId,
    String? frontName,
    ReportDateRange? dateRange,
  }) {
    return ReportFilters(
      projectId: projectId ?? this.projectId,
      frontName: frontName ?? this.frontName,
      dateRange: dateRange ?? this.dateRange,
    );
  }
}

final reportFiltersProvider = StateProvider<ReportFilters>((ref) {
  final now = DateTime.now();
  // Initial project comes from activeProjectIdProvider (set at login / project selector).
  // Falls back to empty; UI auto-selects once availableProjectsProvider resolves.
  final projectId = ref.watch(activeProjectIdProvider);
  return ReportFilters(
    projectId: projectId,
    frontName: 'Todos',
    dateRange: ReportDateRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    ),
  );
});

// Re-export shared provider under legacy name so existing UI code compiles unchanged.
final reportProjectsProvider = availableProjectsProvider;

// ---------------------------------------------------------------------------
// Activity model for reports
// ---------------------------------------------------------------------------

class ReportActivityItem {
  final String id;
  final String activityType;
  final String pk;
  final String frontName;
  final String status;
  final String createdAt;
  final String? assignedName;
  final String? projectId;

  const ReportActivityItem({
    required this.id,
    required this.activityType,
    required this.pk,
    required this.frontName,
    required this.status,
    required this.createdAt,
    this.assignedName,
    this.projectId,
  });

  factory ReportActivityItem.fromJson(Map<String, dynamic> json) {
    return ReportActivityItem(
      id: (json['id'] ?? '').toString(),
      activityType: (json['activity_type'] ?? 'Actividad').toString(),
      pk: (json['pk'] ?? '-').toString(),
      frontName: (json['front'] ?? json['front_name'] ?? 'Sin frente').toString(),
      status: (json['status'] ?? 'PENDIENTE_REVISION').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      assignedName: (json['assignedName'] ?? json['assigned_name'])?.toString(),
      projectId: (json['project_id'])?.toString(),
    );
  }

  String get statusLabel => switch (status.toUpperCase()) {
        'APROBADO' => 'Aprobado',
        'RECHAZADO' => 'Rechazado',
        'PENDIENTE_REVISION' => 'Pendiente revisión',
        _ => status,
      };
}

final reportActivitiesProvider =
    FutureProvider.autoDispose<List<ReportActivityItem>>((ref) async {
  final filters = ref.watch(reportFiltersProvider);
  const client = BackendApiClient();

  try {
  final path =
    '/api/v1/reports/activities?project_id=${Uri.encodeQueryComponent(filters.projectId)}'
    '&date_from=${Uri.encodeQueryComponent(filters.dateRange.start.toUtc().toIso8601String())}'
    '&date_to=${Uri.encodeQueryComponent(filters.dateRange.end.toUtc().toIso8601String())}'
    '&front=${Uri.encodeQueryComponent(filters.frontName)}';

  final decoded = await client.getJson(path);
    if (decoded is! Map<String, dynamic>) return [];
  final items = decoded['items'] as List<dynamic>? ?? const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => ReportActivityItem.fromJson(e))
        .where((item) {
          if (filters.frontName != 'Todos' && filters.frontName.isNotEmpty) {
            return item.frontName
                .toLowerCase()
                .contains(filters.frontName.toLowerCase());
          }
          return true;
        })
        .toList();
  } catch (_) {
    return [];
  }
});

// ---------------------------------------------------------------------------
// PDF Generation
// ---------------------------------------------------------------------------

const _pdfTitleStyle =
    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
const _pdfSubtitleStyle = pw.TextStyle(fontSize: 10);
const _pdfMetaStyle = pw.TextStyle(fontSize: 9);
const _pdfFooterStyle = pw.TextStyle(fontSize: 8);
const _pdfSectionTitleStyle =
    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
const _pdfStatValueStyle =
    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold);
const _pdfCellHeaderStyle = pw.TextStyle(
  fontSize: 9,
  fontWeight: pw.FontWeight.bold,
  color: PdfColors.white,
);
const _pdfCellBodyBaseStyle = pw.TextStyle(fontSize: 8);

/// Generates a PDF report for a list of activities and saves it to disk.
/// Returns the saved [File].
Future<File> generateActivitiesPdf(
  List<ReportActivityItem> items,
  ReportFilters filters, {
  String executiveSummary = '',
  bool includeAudit = true,
  bool includeNotes = false,
  bool includeAttachments = true,
}) async {
  final pdf = pw.Document();
  final now = DateTime.now();
  final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
  final dateRangeFmt =
      '${DateFormat('dd/MM/yyyy').format(filters.dateRange.start)} '
      '- ${DateFormat('dd/MM/yyyy').format(filters.dateRange.end)}';

  // Build sections label for footer
  final sections = <String>[];
  if (includeAudit) sections.add('Auditoría');
  if (includeNotes) sections.add('Notas Internas');
  if (includeAttachments) sections.add('Anexos');
  final sectionsLabel =
      sections.isEmpty ? '' : 'Incluye: ${sections.join(', ')}';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPORTE SAO - ${filters.projectId}',
                    style: _pdfTitleStyle,
                  ),
                  pw.Text(
                    'Periodo: $dateRangeFmt',
                    style: _pdfSubtitleStyle,
                  ),
                  if (filters.frontName != 'Todos')
                    pw.Text(
                      'Frente: ${filters.frontName}',
                      style: _pdfMetaStyle,
                    ),
                ],
              ),
              pw.Text(
                'Generado: ${dateFormatter.format(now)}',
                style: _pdfMetaStyle,
              ),
            ],
          ),
          pw.Divider(),
          pw.SizedBox(height: 4),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SAO - Sistema de Administración Operativa',
              style: _pdfFooterStyle),
          if (sectionsLabel.isNotEmpty)
            pw.Text(sectionsLabel, style: _pdfFooterStyle),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: _pdfFooterStyle),
        ],
      ),
      build: (context) => [
        // Executive summary (if provided)
        if (executiveSummary.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Resumen Ejecutivo', style: _pdfSectionTitleStyle),
                pw.SizedBox(height: 6),
                pw.Text(executiveSummary, style: _pdfSubtitleStyle),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
        ],

        // Stats summary
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfStat('Total', '${items.length}'),
              _pdfStat(
                  'Aprobados',
                  '${items.where((i) => i.status.toUpperCase() == 'APROBADO').length}'),
              _pdfStat(
                  'Pendientes',
                  '${items.where((i) => i.status.toUpperCase() == 'PENDIENTE_REVISION').length}'),
              _pdfStat(
                  'Rechazados',
                  '${items.where((i) => i.status.toUpperCase() == 'RECHAZADO').length}'),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Table header
        pw.Text('Detalle de Actividades', style: _pdfSectionTitleStyle),
        pw.SizedBox(height: 8),

        // Table
        if (items.isEmpty)
          pw.Text('Sin actividades en el periodo seleccionado.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _pdfCell('ID', isHeader: true),
                  _pdfCell('Tipo de Actividad', isHeader: true),
                  _pdfCell('PK', isHeader: true),
                  _pdfCell('Frente', isHeader: true),
                  _pdfCell('Estado', isHeader: true),
                ],
              ),
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final bg = i.isEven ? PdfColors.grey50 : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _pdfCell(item.id.length > 20
                        ? '${item.id.substring(0, 20)}…'
                        : item.id),
                    _pdfCell(item.activityType),
                    _pdfCell(item.pk),
                    _pdfCell(item.frontName),
                    _pdfCell(
                      item.statusLabel,
                      color: switch (item.status.toUpperCase()) {
                        'APROBADO' => PdfColors.green700,
                        'RECHAZADO' => PdfColors.red700,
                        _ => PdfColors.orange700,
                      },
                    ),
                  ],
                );
              }),
            ],
          ),
      ],
    ),
  );

  // Save to documents
  final docsDir = await getApplicationDocumentsDirectory();
  final reportsDir = Directory('${docsDir.path}/SAO_Reportes');
  if (!await reportsDir.exists()) {
    await reportsDir.create(recursive: true);
  }

  final fileName =
      'SAO_${filters.projectId}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
  final file = File('${reportsDir.path}/$fileName');
  await file.writeAsBytes(await pdf.save());
  return file;
}

pw.Widget _pdfStat(String label, String value) {
  return pw.Column(
    children: [
      pw.Text(value, style: _pdfStatValueStyle),
      pw.Text(label, style: _pdfMetaStyle),
    ],
  );
}

pw.Widget _pdfCell(
  String text, {
  bool isHeader = false,
  PdfColor? color,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      text,
      style: isHeader
          ? _pdfCellHeaderStyle
          : _pdfCellBodyBaseStyle.copyWith(color: color ?? PdfColors.black),
    ),
  );
}
