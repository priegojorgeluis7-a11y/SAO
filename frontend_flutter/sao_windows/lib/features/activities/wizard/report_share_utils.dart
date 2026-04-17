import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/format_utils.dart';
import '../../home/models/today_activity.dart';

String buildInitialWhatsAppReport({
  required String projectCode,
  required TodayActivity activity,
  String? customTitle,
  String? resultLabel,
  String? notes,
  List<String> agreements = const [],
  int evidenceCount = 0,
}) {
  final cleanProject = projectCode.trim().isEmpty ? 'N/D' : projectCode.trim().toUpperCase();
  final cleanTitle = activity.title.trim().isEmpty ? 'Actividad operativa' : activity.title.trim();
  final cleanFront = activity.frente.trim();
  final cleanMunicipio = activity.municipio.trim();
  final cleanEstado = activity.estado.trim();
  final cleanResult = (resultLabel ?? '').trim();
  final cleanNotes = (notes ?? '').trim();
  final cleanCustomTitle = (customTitle ?? '').trim();
  final cleanAgreements = agreements
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  final locationParts = <String>[
    if (cleanMunicipio.isNotEmpty) cleanMunicipio,
    if (cleanEstado.isNotEmpty) cleanEstado,
  ];
  final location = locationParts.isEmpty ? 'Sin ubicación registrada' : locationParts.join(', ');

  final scheduleParts = <String>[
    if (activity.horaInicio != null) 'Inicio ${fmtTime(activity.horaInicio)}',
    if (activity.horaFin != null) 'Término ${fmtTime(activity.horaFin)}',
  ];
  final schedule = scheduleParts.isEmpty ? '' : scheduleParts.join(' · ');

  final lines = <String>[
    if (cleanCustomTitle.isNotEmpty) '*$cleanCustomTitle*',
    if (cleanCustomTitle.isNotEmpty) '',
    '*Proyecto:* $cleanProject',
    '*Actividad:* $cleanTitle',
    if (cleanFront.isNotEmpty) '*Frente:* $cleanFront',
    '*Ubicación:* $location',
    if (activity.pk != null) '*PK:* ${formatPk(activity.pk)}',
    if (schedule.isNotEmpty) '*Horario:* $schedule',
    if (cleanResult.isNotEmpty) '*Resultado:* $cleanResult',
    if (cleanNotes.isNotEmpty) ...[
      '',
      '*Resumen:*',
      cleanNotes,
    ],
    if (cleanAgreements.isNotEmpty) ...[
      '',
      '*Acuerdos relevantes:*',
      ...cleanAgreements.map((item) => '• $item'),
    ],
    '',
    '*Estatus:* Terminada',
  ];

  return lines.join('\n');
}

List<String> collectShareableImagePaths(Iterable<String> rawPaths) {
  const allowedExtensions = <String>{'.jpg', '.jpeg', '.png', '.webp', '.heic'};
  final result = <String>[];
  final seen = <String>{};

  for (final rawPath in rawPaths) {
    final path = rawPath.trim();
    if (path.isEmpty || !seen.add(path)) continue;

    final lower = path.toLowerCase();
    final isImage = allowedExtensions.any(lower.endsWith);
    if (!isImage) continue;

    final file = File(path);
    if (file.existsSync()) {
      result.add(path);
    }
  }

  return result;
}

Future<bool> shareReportTextAndImages({
  required String text,
  List<String> imagePaths = const [],
}) async {
  final validImagePaths = collectShareableImagePaths(imagePaths);

  if (validImagePaths.isNotEmpty) {
    try {
      final result = await Share.shareXFiles(
        validImagePaths.map(XFile.new).toList(growable: false),
        text: text,
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      // Fall back to text-only WhatsApp launch below.
    }
  }

  return openWhatsAppWithText(text);
}

Future<bool> openWhatsAppWithText(String text) async {
  final encoded = Uri.encodeComponent(text);
  final candidates = <Uri>[
    Uri.parse('whatsapp://send?text=$encoded'),
    Uri.parse('https://wa.me/?text=$encoded'),
  ];

  for (final uri in candidates) {
    try {
      if (await canLaunchUrl(uri)) {
        final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (opened) return true;
      }
    } catch (_) {
      // Try next candidate.
    }
  }

  return false;
}
