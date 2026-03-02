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

  const EvidenceGalleryPanelPro({
    super.key,
    required this.activity,
    required this.selectedIndex,
    required this.onSelectEvidence,
    this.onCaptionChanged,
  });

  @override
  State<EvidenceGalleryPanelPro> createState() => _EvidenceGalleryPanelProState();
}

class _EvidenceGalleryPanelProState extends State<EvidenceGalleryPanelPro> {
  late Map<String, TextEditingController> _captionControllers;
  late Map<String, TextEditingController> _notesControllers;
  late Map<String, bool> _isEditingCaption;
  final EvidenceRepository _evidenceRepository = EvidenceRepository();
  final Map<String, String> _signedUrlCache = {};
  int? _lastPrefetchIndex;

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
      for (var evidence in widget.activity!.evidences) {
        _captionControllers[evidence.id] =
            TextEditingController(text: evidence.caption ?? '');
        _notesControllers[evidence.id] =
            TextEditingController(text: ''); // TODO: Load from DB if exists
        _isEditingCaption[evidence.id] = false;
      }
    }
  }

  @override
  void didUpdateWidget(EvidenceGalleryPanelPro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity?.evidences.length !=
        widget.activity?.evidences.length) {
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

    // Prefetch skipped for local files on desktop
    _lastPrefetchIndex = nextIndex;
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

  Future<void> _openPdfUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildEvidenceContent(Evidence evidence) {
    if (!_shouldUseSignedUrl(evidence)) {
      final imageUrl = evidence.filePath.startsWith('http')
          ? evidence.filePath
          : 'asset: ${evidence.filePath}';

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
        caption: evidence.caption ?? 'Evidencia',
        latitude: evidence.latitude,
        longitude: evidence.longitude,
        capturedAt: evidence.capturedAt,
        onRetry: () => setState(() {}),
      );
    }

    return FutureBuilder<String?>(
      future: _resolveSignedUrl(evidence),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 8),
                const Text('No fue posible obtener la URL firmada'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _signedUrlCache.remove(evidence.id);
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
          caption: evidence.caption ?? 'Evidencia',
          latitude: evidence.latitude,
          longitude: evidence.longitude,
          capturedAt: evidence.capturedAt,
          onRetry: () {
            _signedUrlCache.remove(evidence.id);
            setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activity == null || widget.activity!.evidences.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(SaoRadii.md),
          border: Border.all(color: SaoColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 64, color: SaoColors.gray400),
              SizedBox(height: SaoSpacing.lg),
              Text(
                'Sin evidencias',
                style:
                    SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
              ),
              SizedBox(height: SaoSpacing.md),
              ElevatedButton.icon(
                onPressed: () => setState(_initializeControllers),
                icon: Icon(Icons.refresh_rounded),
                label: Text('Reintentar carga'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SaoColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activity = widget.activity!;
    final evidence = activity.evidences[widget.selectedIndex];
    _prefetchNextEvidence(activity);
    final gpsDistanceMeters = _calculateDistanceMeters(activity, evidence);
    final gpsMismatch = gpsDistanceMeters != null && gpsDistanceMeters > 50;

    return Column(
      children: [
        // VISOR DE EVIDENCIA (principal)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: SaoColors.surface,
              borderRadius: BorderRadius.circular(SaoRadii.md),
              border: Border.all(color: SaoColors.border),
            ),
            child: Column(
              children: [
                // Header con nav
                Container(
                  padding: EdgeInsets.all(SaoSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: SaoColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_rounded,
                          color: SaoColors.primary),
                      SizedBox(width: SaoSpacing.sm),
                      Expanded(
                        child: Text(
                          'Evidencias (${widget.selectedIndex + 1}/${activity.evidences.length})',
                          style: SaoTypography.sectionTitle
                              .copyWith(fontSize: 14),
                        ),
                      ),
                      // Botones de navegación
                      Row(
                        children: [
                          IconButton(
                            onPressed: widget.selectedIndex > 0
                                ? () => widget.onSelectEvidence(
                                    widget.selectedIndex - 1)
                                : null,
                            icon: Icon(Icons.navigate_before_rounded),
                          ),
                          IconButton(
                            onPressed: widget.selectedIndex <
                                    activity.evidences.length - 1
                                ? () => widget.onSelectEvidence(
                                    widget.selectedIndex + 1)
                                : null,
                            icon: Icon(Icons.navigate_next_rounded),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: SaoSpacing.sm,
                              vertical: SaoSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: SaoColors.error,
                              borderRadius: BorderRadius.circular(SaoRadii.full),
                            ),
                            child: Text(
                              'Error de integridad territorial · ${gpsDistanceMeters!.toStringAsFixed(0)}m',
                              style: SaoTypography.caption.copyWith(
                                color: Colors.white,
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

        SizedBox(height: SaoSpacing.md),

        // PIE DE FOTO
        Container(
          decoration: BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(SaoRadii.md),
            border: Border.all(color: SaoColors.border),
          ),
          padding: EdgeInsets.all(SaoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.title_rounded, size: 16, color: SaoColors.gray600),
                  SizedBox(width: SaoSpacing.sm),
                  Text(
                    'Pie de foto',
                    style: SaoTypography.sectionTitle.copyWith(fontSize: 13),
                  ),
                  Spacer(),
                  if (!_isEditingCaption[evidence.id]!)
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => setState(() => _isEditingCaption[evidence.id] = true),
                      tooltip: 'Editar pie de foto',
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                ],
              ),
              SizedBox(height: SaoSpacing.sm),
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
                        contentPadding: EdgeInsets.all(SaoSpacing.sm),
                        isDense: true,
                      ),
                      style: SaoTypography.bodyText.copyWith(fontSize: 13),
                    ),
                    SizedBox(height: SaoSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _captionControllers[evidence.id]!.text = evidence.caption ?? '';
                            setState(() => _isEditingCaption[evidence.id] = false);
                          },
                          child: Text('Cancelar'),
                        ),
                        SizedBox(width: SaoSpacing.xs),
                        ElevatedButton(
                          onPressed: () => _saveCaption(evidence.id),
                          child: Text('Guardar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SaoColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: SaoSpacing.md,
                              vertical: SaoSpacing.sm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Text(
                  evidence.caption?.isNotEmpty == true
                      ? evidence.caption!
                      : 'Sin descripción',
                  style: SaoTypography.bodyText.copyWith(
                    fontSize: 13,
                    color: evidence.caption?.isNotEmpty == true
                        ? SaoColors.gray700
                        : SaoColors.gray500,
                    fontStyle: evidence.caption?.isNotEmpty == true
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: SaoSpacing.md),

        // METADATOS
        Container(
          decoration: BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(SaoRadii.md),
            border: Border.all(color: SaoColors.border),
          ),
          padding: EdgeInsets.all(SaoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: SaoColors.gray600),
                  SizedBox(width: SaoSpacing.sm),
                  Text(
                    'Metadatos',
                    style: SaoTypography.sectionTitle.copyWith(fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: SaoSpacing.md),
              _buildMetadataRow(
                'Fecha y hora',
                evidence.capturedAt != null
                    ? DateFormat('dd/MM/yyyy HH:mm:ss').format(evidence.capturedAt!)
                    : 'No disponible',
                Icons.access_time_rounded,
              ),
              SizedBox(height: SaoSpacing.sm),
              _buildMetadataRow(
                'Coordenadas GPS',
                evidence.latitude != null && evidence.longitude != null
                    ? '${evidence.latitude!.toStringAsFixed(6)}°, ${evidence.longitude!.toStringAsFixed(6)}°'
                    : 'No disponible',
                Icons.location_on_outlined,
                valueColor: gpsMismatch ? SaoColors.error : null,
              ),
              if (gpsDistanceMeters != null) ...[
                SizedBox(height: SaoSpacing.sm),
                _buildMetadataRow(
                  'Distancia al punto',
                  '${gpsDistanceMeters.toStringAsFixed(1)} m',
                  Icons.straighten_rounded,
                  valueColor: gpsMismatch ? SaoColors.error : SaoColors.success,
                ),
              ],
              SizedBox(height: SaoSpacing.sm),
              _buildMetadataRow(
                'Archivo',
                evidence.filePath.split('/').last,
                Icons.insert_drive_file_outlined,
              ),
            ],
          ),
        ),

        SizedBox(height: SaoSpacing.md),

        // NOTAS INTERNAS
        Container(
          decoration: BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(SaoRadii.md),
            border: Border.all(color: SaoColors.border),
          ),
          padding: EdgeInsets.all(SaoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 16, color: SaoColors.gray600),
                  SizedBox(width: SaoSpacing.sm),
                  Text(
                    'Notas internas',
                    style: SaoTypography.sectionTitle.copyWith(fontSize: 13),
                  ),
                  Spacer(),
                  Tooltip(
                    message: 'Las notas internas solo son visibles para validadores',
                    child: Icon(Icons.help_outline_rounded, size: 14, color: SaoColors.gray500),
                  ),
                ],
              ),
              SizedBox(height: SaoSpacing.sm),
              TextField(
                controller: _notesControllers[evidence.id],
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Añadir observaciones internas sobre esta evidencia...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SaoRadii.sm),
                  ),
                  contentPadding: EdgeInsets.all(SaoSpacing.sm),
                  isDense: true,
                ),
                style: SaoTypography.bodyText.copyWith(fontSize: 12),
                onChanged: (value) {
                  // Auto-save notes (debounced in real implementation)
                },
              ),
              SizedBox(height: SaoSpacing.sm),
              Text(
                'Estas notas no serán visibles en el reporte final',
                style: SaoTypography.caption.copyWith(
                  fontSize: 10,
                  color: SaoColors.gray500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
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
        Icon(icon, size: 14, color: SaoColors.gray500),
        SizedBox(width: SaoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: SaoTypography.caption.copyWith(
                  fontSize: 10,
                  color: SaoColors.gray500,
                ),
              ),
              Text(
                value,
                style: SaoTypography.caption.copyWith(
                  fontSize: 11,
                  color: valueColor ?? SaoColors.gray700,
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