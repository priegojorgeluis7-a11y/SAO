// lib/ui/widgets/sao_evidence_viewer.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_typography.dart';

/// Visor avanzado de evidencias con funciones profesionales
///
/// Características:
/// - Zoom con rueda del mouse (1x - 5x)
/// - Rotación de imagen (90° incrementos)
/// - Metadatos superpuestos mínimos
/// - Navegación entre evidencias
/// - Modo pantalla completa
class SaoEvidenceViewer extends StatefulWidget {
  const SaoEvidenceViewer({
    super.key,
    required this.imageUrl,
    this.caption,
    this.latitude,
    this.longitude,
    this.capturedAt,
    this.currentIndex,
    this.totalCount,
    this.onPrevious,
    this.onNext,
    this.onFullscreen,
    this.onMapView,
    this.onRetry,
  });

  final String imageUrl;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;
  final int? currentIndex;
  final int? totalCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFullscreen;
  final VoidCallback? onMapView;
  final VoidCallback? onRetry;

  @override
  State<SaoEvidenceViewer> createState() => _SaoEvidenceViewerState();
}

class _SaoEvidenceViewerState extends State<SaoEvidenceViewer> {
  final TransformationController _transformationController =
      TransformationController();

  double _scale = 1.0;
  bool _lensEnabled = false;
  bool _isHovering = false;
  Offset _lensPosition = Offset.zero;

  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _scaleIncrement = 0.25;

  void _updateScaleFromController() {
    final nextScale = _transformationController.value
        .getMaxScaleOnAxis()
        .clamp(_minScale, _maxScale)
        .toDouble();

    if ((_scale - nextScale).abs() > 0.001 && mounted) {
      setState(() => _scale = nextScale);
    }
  }

  void _applyScale(double requestedScale) {
    final clampedScale = requestedScale.clamp(_minScale, _maxScale).toDouble();

    if (clampedScale == _minScale) {
      _transformationController.value = Matrix4.identity();
    } else {
      final translation = _transformationController.value.getTranslation();
      _transformationController.value = Matrix4.identity()
        ..translate(translation.x, translation.y)
        ..scale(clampedScale);
    }

    setState(() => _scale = clampedScale);
  }

  void _zoomIn() => _applyScale(_scale + _scaleIncrement);

  void _zoomOut() => _applyScale(_scale - _scaleIncrement);

  void _resetZoom() => _applyScale(_minScale);

  void _handleScroll(PointerScrollEvent event) {
    if (event.scrollDelta.dy < 0) {
      _zoomIn();
    } else {
      _zoomOut();
    }
  }

  void _retryLoad() {
    if (widget.onRetry != null) {
      widget.onRetry!.call();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Widget _buildErrorWidget() {
    return Container(
      color: SaoColors.gray100,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SaoSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                size: 64,
                color: SaoColors.gray500,
              ),
              const SizedBox(height: SaoSpacing.md),
              Text(
                'No se pudo cargar la evidencia',
                style: SaoTypography.bodyText.copyWith(
                  color: SaoColors.gray600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SaoSpacing.sm),
              TextButton.icon(
                onPressed: _retryLoad,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent({required BoxFit fit}) {
    final source = widget.imageUrl.trim();
    if (source.startsWith('asset:')) {
      return Image.asset(
        source.replaceFirst('asset:', '').trim(),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    if (source.startsWith('file://')) {
      final file = File(Uri.parse(source).toFilePath());
      return Image.file(
        file,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    final localFile = File(source);
    if (!source.startsWith('http://') &&
        !source.startsWith('https://') &&
        localFile.existsSync()) {
      return Image.file(
        localFile,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    return Image.network(
      source,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Cargando evidencia...',
                style: SaoTypography.bodyText.copyWith(
                  color: SaoColors.gray700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header con controles
        Container(
          padding: const EdgeInsets.all(SaoSpacing.md),
          decoration: BoxDecoration(
            color: SaoColors.surfaceFor(context),
            border:
                Border(bottom: BorderSide(color: SaoColors.borderFor(context))),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.photo_library_rounded,
                size: 20,
                color: SaoColors.primary,
              ),
              const SizedBox(width: SaoSpacing.sm),
              Text(
                widget.currentIndex != null && widget.totalCount != null
                    ? 'Evidencia ${widget.currentIndex! + 1} de ${widget.totalCount}'
                    : 'Evidencia',
                style: SaoTypography.sectionTitle.copyWith(fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_rounded),
                onPressed: _scale > _minScale ? _zoomOut : null,
                tooltip: 'Alejar',
              ),
              Text(
                '${(_scale * 100).round()}%',
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.textMutedFor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _scale < _maxScale ? _zoomIn : null,
                tooltip: 'Acercar',
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: _scale > _minScale ? _resetZoom : null,
                tooltip: 'Restablecer zoom',
              ),
              IconButton(
                icon: Icon(
                  _lensEnabled
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () {
                  setState(() => _lensEnabled = !_lensEnabled);
                },
                tooltip: _lensEnabled ? 'Desactivar lupa' : 'Activar lupa',
              ),

              // Controles de navegación
              if (widget.onPrevious != null)
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed:
                      widget.currentIndex != null && widget.currentIndex! > 0
                          ? widget.onPrevious
                          : null,
                  tooltip: 'Anterior (←)',
                ),
              if (widget.onNext != null)
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: widget.currentIndex != null &&
                          widget.totalCount != null &&
                          widget.currentIndex! < widget.totalCount! - 1
                      ? widget.onNext
                      : null,
                  tooltip: 'Siguiente (→)',
                ),
            ],
          ),
        ),

        // Visor de imagen con overlay
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const lensSize = 140.0;
              const lensZoom = 2.2;
              final maxX = math.max(0.0, constraints.maxWidth - lensSize);
              final maxY = math.max(0.0, constraints.maxHeight - lensSize);
              final safeX = (_lensPosition.dx - lensSize / 2).clamp(0.0, maxX);
              final safeY = (_lensPosition.dy - lensSize / 2).clamp(0.0, maxY);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        _handleScroll(event);
                      }
                    },
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isHovering = true),
                      onExit: (_) => setState(() => _isHovering = false),
                      onHover: (event) {
                        if (!_lensEnabled) return;
                        setState(() => _lensPosition = event.localPosition);
                      },
                      child: ClipRect(
                        child: Container(
                          color: SaoColors.surfaceRaisedFor(context),
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: _minScale,
                            maxScale: _maxScale,
                            panEnabled: _scale > _minScale,
                            scaleEnabled: true,
                            clipBehavior: Clip.none,
                            onInteractionUpdate: (_) =>
                                _updateScaleFromController(),
                            onInteractionEnd: (_) =>
                                _updateScaleFromController(),
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Padding(
                                padding: const EdgeInsets.all(SaoSpacing.sm),
                                child: _buildImageContent(fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_lensEnabled && _isHovering)
                    Positioned(
                      left: safeX,
                      top: safeY,
                      child: ClipOval(
                        child: Container(
                          width: lensSize,
                          height: lensSize,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: SaoColors.primary,
                              width: 2,
                            ),
                          ),
                          child: Transform.translate(
                            offset: Offset(
                              -_lensPosition.dx * (lensZoom - 1),
                              -_lensPosition.dy * (lensZoom - 1),
                            ),
                            child: Transform.scale(
                              scale: lensZoom,
                              child: _buildImageContent(fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.all(SaoSpacing.sm),
                      decoration: BoxDecoration(
                        color: SaoColors.gray900.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.capturedAt != null)
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm')
                                  .format(widget.capturedAt!),
                              style: SaoTypography.caption.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Footer: compacto sin altura fija
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.md,
            vertical: SaoSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: SaoColors.surfaceFor(context),
            border:
                Border(top: BorderSide(color: SaoColors.borderFor(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.caption ?? 'Sin descripción',
                  style: SaoTypography.caption.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: SaoSpacing.sm),
              const Icon(Icons.info_outline, size: 12),
            ],
          ),
        ),
      ],
    );
  }
}
