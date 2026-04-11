import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../core/config/data_mode.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/sao_evidence_viewer.dart';

/// Panel de Evidencias PRO con:
/// 1. Visor de evidencias mejorado
/// 2. Edición de pies de foto (captions) con autosave
/// 3. Minimap + Notas internas integrado
class EvidenceGalleryPanelPro extends StatefulWidget {
  final ActivityWithDetails? activity;
  final int selectedIndex;
  final Function(int) onSelectEvidence;
  final Function(String evidenceId, String caption)? onCaptionChanged;
  final EvidenceRepository? evidenceRepository;

  const EvidenceGalleryPanelPro({
    super.key,
    required this.activity,
    required this.selectedIndex,
    required this.onSelectEvidence,
    this.onCaptionChanged,
    this.evidenceRepository,
  });

  @override
  State<EvidenceGalleryPanelPro> createState() => _EvidenceGalleryPanelProState();
}

class _EvidenceGalleryPanelProState extends State<EvidenceGalleryPanelPro> {
  late Map<String, TextEditingController> _captionControllers;
  late Map<String, TextEditingController> _notesControllers;
  late Map<String, bool> _isEditingCaption;
  final EvidenceRepository _defaultEvidenceRepository = EvidenceRepository();
  final Map<String, String> _signedUrlCache = {};
  final Map<String, Future<String?>> _signedUrlFutureCache = {};
  int? _lastPrefetchIndex;

  EvidenceRepository get _evidenceRepository =>
      widget.evidenceRepository ?? _defaultEvidenceRepository;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _captionControllers = {};
    _notesControllers = {};
    _isEditingCaption = {};

    if (widget.activity != null) {
      for (final entry in widget.activity!.evidences.asMap().entries) {
        final evidence = entry.value;
        _captionControllers[evidence.id] = TextEditingController(
          text: _resolvedCaptionForEvidence(evidence, indexHint: entry.key),
        );
        _notesControllers[evidence.id] =
            TextEditingController(text: ''); // TODO: Load from DB if exists
        _isEditingCaption[evidence.id] = false;
      }
    }
  }

  @override
  void didUpdateWidget(EvidenceGalleryPanelPro oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activityChanged =
        oldWidget.activity?.activity.id != widget.activity?.activity.id;
    if (activityChanged ||
        oldWidget.activity?.evidences.length !=
            widget.activity?.evidences.length) {
      if (activityChanged) {
        _signedUrlCache.clear();
        _signedUrlFutureCache.clear();
        _lastPrefetchIndex = null;
      }
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    for (var controller in _captionControllers.values) {
      controller.dispose();
    }
    for (var controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _firstNonEmptyText(Iterable<Object?> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  String _resolvedCaptionForEvidence(Evidence evidence, {int? indexHint}) {
    final direct = _firstNonEmptyText([
      _captionControllers[evidence.id]?.text,
      evidence.caption,
    ]);
    if (direct != null) {
      return direct;
    }

    final rawWizardEvidences = widget.activity?.wizardPayload?['evidences'];
    if (rawWizardEvidences is List) {
      Map<String, dynamic>? matchedPayload;
      final evidenceId = evidence.id.trim();

      for (final raw in rawWizardEvidences) {
        if (raw is! Map) continue;
        final payload = raw.cast<String, dynamic>();
        if ((payload['id'] ?? '').toString().trim() == evidenceId) {
          matchedPayload = payload;
          break;
        }
      }

      if (matchedPayload == null &&
          indexHint != null &&
          indexHint >= 0 &&
          indexHint < rawWizardEvidences.length) {
        final raw = rawWizardEvidences[indexHint];
        if (raw is Map) {
          matchedPayload = raw.cast<String, dynamic>();
        }
      }

      final payloadCaption = _firstNonEmptyText([
        matchedPayload?['caption'],
        matchedPayload?['description'],
        matchedPayload?['descripcion'],
        matchedPayload?['notes'],
      ]);
      if (payloadCaption != null) {
        return payloadCaption;
      }
    }

    return '';
  }

  void _saveCaption(String evidenceId) {
    final controller = _captionControllers[evidenceId];
    if (controller != null) {
      widget.onCaptionChanged?.call(evidenceId, controller.text);
      setState(() => _isEditingCaption[evidenceId] = false);
    }
  }

  void _prefetchNextEvidence(ActivityWithDetails activity) {
    final nextIndex = widget.selectedIndex + 1;
    if (nextIndex >= activity.evidences.length) return;
    if (_lastPrefetchIndex == nextIndex) return;

    _lastPrefetchIndex = nextIndex;
    unawaited(_warmEvidence(activity.evidences[nextIndex]));
  }

  void _clearSignedUrlState(String evidenceId) {
    _signedUrlCache.remove(evidenceId);
    _signedUrlFutureCache.remove(evidenceId);
  }

  Future<void> _warmEvidence(Evidence evidence) async {
    if (_isPendingServerEvidence(evidence) || !_shouldUseSignedUrl(evidence)) {
      return;
    }

    final future = _signedUrlFutureCache.putIfAbsent(
      evidence.id,
      () => _resolveSignedUrl(evidence),
    );
    final signedUrl = await future;
    if (!mounted || signedUrl == null || signedUrl.isEmpty) {
      return;
    }
    if (_isPdfEvidence(evidence, signedUrl)) {
      return;
    }

    await precacheImage(NetworkImage(signedUrl), context);
  }

  double? _calculateDistanceMeters(ActivityWithDetails activity, Evidence evidence) {
    if (activity.activity.latitude == null ||
        activity.activity.longitude == null ||
        evidence.latitude == null ||
        evidence.longitude == null) {
      return null;
    }

    final lat1 = activity.activity.latitude!;
    final lon1 = activity.activity.longitude!;
    final lat2 = evidence.latitude!;
    final lon2 = evidence.longitude!;

    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    const earthRadius = 6371000.0;
    return earthRadius * c;
  }

  bool _shouldUseSignedUrl(Evidence evidence) {
    if (AppDataMode.backendBaseUrl.trim().isEmpty) {
      return false;
    }
    return evidence.filePath.startsWith('backend://');
  }

  bool _isPendingServerEvidence(Evidence evidence) {
    final rawPath = evidence.filePath.trim();
    final lowerPath = rawPath.toLowerCase();
    if (lowerPath.isEmpty || lowerPath.startsWith('pending://')) {
      return true;
    }
    if (lowerPath.startsWith('backend://') ||
        lowerPath.startsWith('http://') ||
        lowerPath.startsWith('https://') ||
        lowerPath.startsWith('file://')) {
      return false;
    }

    return !File(rawPath).existsSync();
  }

  Widget _buildPendingEvidencePlaceholder(Evidence evidence) {
    return Container(
      color: SaoColors.surfaceRaisedFor(context),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SaoSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                size: 56,
                color: SaoColors.warning,
              ),
              const SizedBox(height: SaoSpacing.md),
              Text(
                'La evidencia aún no está disponible en el servidor',
                style: SaoTypography.bodyText.copyWith(
                  color: SaoColors.textFor(context),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SaoSpacing.sm),
              Text(
                'Sincroniza nuevamente desde el móvil para terminar la carga de la foto y vuelve a abrir esta actividad.',
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.textMutedFor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SaoSpacing.md),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _clearSignedUrlState(evidence.id);
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPdfEvidence(Evidence evidence, String? resolvedUrl) {
    return evidence.fileType.toUpperCase() == 'DOCUMENT' ||
        evidence.filePath.toLowerCase().endsWith('.pdf') ||
        (resolvedUrl?.toLowerCase().contains('.pdf') ?? false);
  }

  Future<String?> _resolveSignedUrl(Evidence evidence) async {
    if (!_shouldUseSignedUrl(evidence)) {
      return null;
    }
    if (_signedUrlCache.containsKey(evidence.id)) {
      return _signedUrlCache[evidence.id];
    }

    final signedUrl = await _evidenceRepository.getDownloadSignedUrl(evidence.id);
    _signedUrlCache[evidence.id] = signedUrl;
    return signedUrl;
  }

  Widget _buildLoadingPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Cargando evidencia del servidor...',
            style: SaoTypography.bodyText.copyWith(
              color: SaoColors.textFor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'La primera carga puede tardar unos segundos.',
            style: SaoTypography.caption.copyWith(
              color: SaoColors.textMutedFor(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildEvidenceContent(Evidence evidence) {
    final displayCaption = _resolvedCaptionForEvidence(
      evidence,
      indexHint: widget.selectedIndex,
    );

    if (_isPendingServerEvidence(evidence)) {
      return _buildPendingEvidencePlaceholder(evidence);
    }

    if (!_shouldUseSignedUrl(evidence)) {
      final rawPath = evidence.filePath.trim();
      final imageUrl = rawPath.startsWith('http') || rawPath.startsWith('file://')
          ? rawPath
          : File(rawPath).uri.toString();

      if (_isPdfEvidence(evidence, imageUrl)) {
        return Center(
          child: ElevatedButton.icon(
            onPressed: () => _openPdfUrl(imageUrl),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Abrir PDF'),
          ),
        );
      }

      return SaoEvidenceViewer(
        imageUrl: imageUrl,
        caption: displayCaption.isNotEmpty ? displayCaption : 'Evidencia',
        latitude: evidence.latitude,
        longitude: evidence.longitude,
        capturedAt: evidence.capturedAt,
        onRetry: () => setState(() {}),
      );
    }

    final cachedSignedUrl = _signedUrlCache[evidence.id];
    if (cachedSignedUrl != null && cachedSignedUrl.isNotEmpty) {
      final signedUrl = cachedSignedUrl;
      if (_isPdfEvidence(evidence, signedUrl)) {
        return Center(
          child: ElevatedButton.icon(
            onPressed: () => _openPdfUrl(signedUrl),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Abrir PDF firmado'),
          ),
        );
      }

      return SaoEvidenceViewer(
        imageUrl: signedUrl,
        caption: displayCaption.isNotEmpty ? displayCaption : 'Evidencia',
        latitude: evidence.latitude,
        longitude: evidence.longitude,
        capturedAt: evidence.capturedAt,
        onRetry: () {
          _clearSignedUrlState(evidence.id);
          setState(() {});
        },
      );
    }

    final signedUrlFuture = _signedUrlFutureCache.putIfAbsent(
      evidence.id,
      () => _resolveSignedUrl(evidence),
    );

    return FutureBuilder<String?>(
      future: signedUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder();
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 8),
                const Text('La evidencia tardó demasiado o no pudo abrirse'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _clearSignedUrlState(evidence.id);
                    setState(() {});
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        final signedUrl = snapshot.data!;
        if (_isPdfEvidence(evidence, signedUrl)) {
          return Center(
            child: ElevatedButton.icon(
              onPressed: () => _openPdfUrl(signedUrl),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Abrir PDF firmado'),
            ),
          );
        }

        return SaoEvidenceViewer(
          imageUrl: signedUrl,
          caption: displayCaption.isNotEmpty ? displayCaption : 'Evidencia',
          latitude: evidence.latitude,
          longitude: evidence.longitude,
          capturedAt: evidence.capturedAt,
          onRetry: () {
            _clearSignedUrlState(evidence.id);
            setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = SaoColors.surfaceFor(context);
    final borderColor = SaoColors.borderFor(context);
    final textColor = SaoColors.textFor(context);
    final mutedTextColor = SaoColors.textMutedFor(context);
    if (widget.activity == null || widget.activity!.evidences.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(SaoRadii.md),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library_outlined,
                  size: 64, color: SaoColors.gray400),
              const SizedBox(height: SaoSpacing.lg),
              Text(
                'Sin evidencias',
                style: SaoTypography.bodyText.copyWith(color: mutedTextColor),
              ),
              const SizedBox(height: SaoSpacing.md),
              ElevatedButton.icon(
                onPressed: () => setState(_initializeControllers),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar carga'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaoColors.primary,
                  foregroundColor: SaoColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activity = widget.activity!;
    final safeSelectedIndex = widget.selectedIndex.clamp(0, activity.evidences.length - 1);
    final evidence = activity.evidences[safeSelectedIndex];
    final displayCaption = _resolvedCaptionForEvidence(
      evidence,
      indexHint: safeSelectedIndex,
    );

    _captionControllers.putIfAbsent(
      evidence.id,
      () => TextEditingController(text: displayCaption),
    );
    _notesControllers.putIfAbsent(
      evidence.id,
      () => TextEditingController(text: ''),
    );
    _isEditingCaption.putIfAbsent(evidence.id, () => false);

    _prefetchNextEvidence(activity);
    final gpsDistanceMeters = _calculateDistanceMeters(activity, evidence);
    final gpsMismatch = gpsDistanceMeters != null && gpsDistanceMeters > 50;

    return Column(
      children: [
        // VISOR DE EVIDENCIA (principal)
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(SaoRadii.md),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // Header con nav
                Container(
                  padding: const EdgeInsets.all(SaoSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_rounded,
                          color: textColor),
                      const SizedBox(width: SaoSpacing.sm),
                      Expanded(
                        child: Text(
                          'Evidencias (${safeSelectedIndex + 1}/${activity.evidences.length})',
                          style: SaoTypography.sectionTitle,
                        ),
                      ),
                      // Botones de navegación
                      Row(
                        children: [
                          IconButton(
                            onPressed: safeSelectedIndex > 0
                                ? () => widget.onSelectEvidence(
                                    safeSelectedIndex - 1)
                                : null,
                            icon: const Icon(Icons.navigate_before_rounded),
                          ),
                          IconButton(
                            onPressed: safeSelectedIndex <
                                    activity.evidences.length - 1
                                ? () => widget.onSelectEvidence(
                                    safeSelectedIndex + 1)
                                : null,
                            icon: const Icon(Icons.navigate_next_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Visor
                Expanded(
                  child: Stack(
                    children: [
                      _buildEvidenceContent(evidence),
                      if (gpsMismatch)
                        Positioned(
                          left: SaoSpacing.md,
                          top: SaoSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SaoSpacing.sm,
                              vertical: SaoSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: SaoColors.error,
                              borderRadius: BorderRadius.circular(SaoRadii.full),
                            ),
                            child: Text(
                              'Error de integridad territorial · ${gpsDistanceMeters.toStringAsFixed(0)}m',
                              style: SaoTypography.caption.copyWith(
                                color: SaoColors.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: SaoSpacing.md),

        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(SaoRadii.md),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(SaoSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates_outlined,
                              size: 16, color: mutedTextColor),
                          const SizedBox(width: SaoSpacing.sm),
                          const Text(
                            'Resumen rápido',
                            style: SaoTypography.sectionTitle,
                          ),
                        ],
                      ),
                      const SizedBox(height: SaoSpacing.sm),
                      Wrap(
                        spacing: SaoSpacing.sm,
                        runSpacing: SaoSpacing.sm,
                        children: [
                          _buildQuickStatChip(
                            icon: Icons.access_time_rounded,
                            label: 'Captura',
                            value: DateFormat('dd/MM HH:mm').format(evidence.capturedAt),
                          ),
                          _buildQuickStatChip(
                            icon: Icons.location_on_outlined,
                            label: 'GPS',
                            value: evidence.latitude != null && evidence.longitude != null
                                ? 'Disponible'
                                : 'No disponible',
                            color: gpsMismatch ? SaoColors.error : null,
                          ),
                          _buildQuickStatChip(
                            icon: Icons.insert_drive_file_outlined,
                            label: 'Archivo',
                            value: evidence.fileType.toUpperCase() == 'DOCUMENT'
                                ? 'PDF'
                                : 'Imagen',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: SaoSpacing.md),

                // PIE DE FOTO
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(SaoRadii.md),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(SaoSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.title_rounded, size: 16, color: mutedTextColor),
                          const SizedBox(width: SaoSpacing.sm),
                          const Text(
                            'Pie de foto',
                            style: SaoTypography.sectionTitle,
                          ),
                          const Spacer(),
                          if (!_isEditingCaption[evidence.id]!)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: () => setState(() => _isEditingCaption[evidence.id] = true),
                              tooltip: 'Editar pie de foto',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            ),
                        ],
                      ),
                      const SizedBox(height: SaoSpacing.sm),
                      if (_isEditingCaption[evidence.id]!)
                        Column(
                          children: [
                            TextField(
                              controller: _captionControllers[evidence.id],
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Descripción de la evidencia...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(SaoRadii.sm),
                                ),
                                contentPadding: const EdgeInsets.all(SaoSpacing.sm),
                                isDense: true,
                              ),
                              style: SaoTypography.bodyText,
                            ),
                            const SizedBox(height: SaoSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    final captionController = _captionControllers[evidence.id];
                                    if (captionController != null) {
                                      captionController.text = displayCaption;
                                    }
                                    setState(() => _isEditingCaption[evidence.id] = false);
                                  },
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: SaoSpacing.xs),
                                ElevatedButton(
                                  onPressed: () => _saveCaption(evidence.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SaoColors.primary,
                                    foregroundColor: SaoColors.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: SaoSpacing.md,
                                      vertical: SaoSpacing.sm,
                                    ),
                                  ),
                                  child: const Text('Guardar'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Text(
                          displayCaption.isNotEmpty
                              ? displayCaption
                              : 'Sin descripción',
                          style: SaoTypography.bodyText.copyWith(
                            color: displayCaption.isNotEmpty
                              ? textColor
                              : mutedTextColor,
                            fontStyle: displayCaption.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: SaoSpacing.md),

                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(SaoRadii.md),
                    border: Border.all(color: borderColor),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: SaoSpacing.md,
                        vertical: SaoSpacing.xs,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        SaoSpacing.md,
                        0,
                        SaoSpacing.md,
                        SaoSpacing.md,
                      ),
                      leading: Icon(Icons.info_outline_rounded,
                          size: 16, color: mutedTextColor),
                      title: const Text(
                        'Metadatos completos',
                        style: SaoTypography.sectionTitle,
                      ),
                      subtitle: Text(
                        'Fecha, GPS, distancia y archivo',
                        style: SaoTypography.caption.copyWith(
                          color: mutedTextColor,
                        ),
                      ),
                      children: [
                        _buildMetadataRow(
                          'Fecha y hora',
                          DateFormat('dd/MM/yyyy HH:mm:ss').format(evidence.capturedAt),
                          Icons.access_time_rounded,
                        ),
                        const SizedBox(height: SaoSpacing.sm),
                        _buildMetadataRow(
                          'Coordenadas GPS',
                          evidence.latitude != null && evidence.longitude != null
                              ? '${evidence.latitude!.toStringAsFixed(6)}°, ${evidence.longitude!.toStringAsFixed(6)}°'
                              : 'No disponible',
                          Icons.location_on_outlined,
                          valueColor: gpsMismatch ? SaoColors.error : null,
                        ),
                        if (gpsDistanceMeters != null) ...[
                          const SizedBox(height: SaoSpacing.sm),
                          _buildMetadataRow(
                            'Distancia al punto',
                            '${gpsDistanceMeters.toStringAsFixed(1)} m',
                            Icons.straighten_rounded,
                            valueColor: gpsMismatch ? SaoColors.error : SaoColors.success,
                          ),
                        ],
                        const SizedBox(height: SaoSpacing.sm),
                        _buildMetadataRow(
                          'Archivo',
                          evidence.filePath.split('/').last,
                          Icons.insert_drive_file_outlined,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: SaoSpacing.md),

                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(SaoRadii.md),
                    border: Border.all(color: borderColor),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: SaoSpacing.md,
                        vertical: SaoSpacing.xs,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        SaoSpacing.md,
                        0,
                        SaoSpacing.md,
                        SaoSpacing.md,
                      ),
                      leading: Icon(Icons.edit_note_rounded,
                          size: 16, color: mutedTextColor),
                      title: const Text(
                        'Notas internas',
                        style: SaoTypography.sectionTitle,
                      ),
                      subtitle: Text(
                        'Solo visibles para validadores',
                        style: SaoTypography.caption.copyWith(
                          color: mutedTextColor,
                        ),
                      ),
                      children: [
                        TextField(
                          controller: _notesControllers[evidence.id],
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Añadir observaciones internas sobre esta evidencia...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(SaoRadii.sm),
                            ),
                            contentPadding: const EdgeInsets.all(SaoSpacing.sm),
                            isDense: true,
                          ),
                          style: SaoTypography.bodyText,
                          onChanged: (value) {
                            // Auto-save notes (debounced in real implementation)
                          },
                        ),
                        const SizedBox(height: SaoSpacing.sm),
                        Text(
                          'Estas notas no serán visibles en el reporte final',
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.gray500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatChip({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SaoSpacing.sm,
        vertical: SaoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SaoRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: SaoSpacing.xs),
          Text(
            '$label: $value',
            style: SaoTypography.caption.copyWith(
              color: SaoColors.textFor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: SaoColors.textMutedFor(context)),
        const SizedBox(width: SaoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.textMutedFor(context),
                ),
              ),
              Text(
                value,
                style: SaoTypography.caption.copyWith(
                  color: valueColor ?? SaoColors.textFor(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}