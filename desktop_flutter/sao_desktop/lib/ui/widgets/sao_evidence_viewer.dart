// lib/ui/widgets/sao_evidence_viewer.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
/// - Mini-mapa con coordenadas GPS
/// - Metadatos superpuestos (fecha/hora original)
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
  double _scale = 1.0;
  int _rotationDegrees = 0; // 0, 90, 180, 270
  Offset _offset = Offset.zero;
  bool _lensEnabled = false;
  bool _isHovering = false;
  Offset _lensPosition = Offset.zero;
  
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _scaleIncrement = 0.2;

  void _handleScroll(PointerScrollEvent event) {
    setState(() {
      // Scroll negativo = zoom in, positivo = zoom out
      if (event.scrollDelta.dy < 0) {
        _scale = (_scale + _scaleIncrement).clamp(_minScale, _maxScale);
      } else {
        _scale = (_scale - _scaleIncrement).clamp(_minScale, _maxScale);
      }

      // Resetear offset si volvemos a escala 1.0
      if (_scale == _minScale) {
        _offset = Offset.zero;
      }
    });
  }

  void _handleRotate() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
    });
  }

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _rotationDegrees = 0;
      _offset = Offset.zero;
    });
  }

  void _retryLoad() {
    if (widget.onRetry != null) {
      widget.onRetry!.call();
      return;
    }
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_scale > 1.0) {
      setState(() {
        _offset += details.delta;
      });
    }
  }

  String get _formattedCoordinates {
    if (widget.latitude == null || widget.longitude == null) {
      return 'Sin coordenadas';
    }
    return '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}';
  }

  Widget _buildErrorWidget() {
    return Container(
      color: SaoColors.gray100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: SaoColors.gray500,
          ),
          SizedBox(height: SaoSpacing.md),
          Text(
            'No se pudo cargar la evidencia',
            style: SaoTypography.bodyText.copyWith(
              color: SaoColors.gray600,
            ),
          ),
          SizedBox(height: SaoSpacing.sm),
          TextButton.icon(
            onPressed: () => setState(() {}),
            icon: Icon(Icons.refresh_rounded),
            label: Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header con controles
        Container(
          padding: EdgeInsets.all(SaoSpacing.md),
          decoration: BoxDecoration(
            color: SaoColors.surface,
            border: Border(bottom: BorderSide(color: SaoColors.border)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.photo_library_rounded,
                size: 20,
                color: SaoColors.primary,
              ),
              SizedBox(width: SaoSpacing.sm),
              Text(
                widget.currentIndex != null && widget.totalCount != null
                    ? 'Evidencia ${widget.currentIndex! + 1} de ${widget.totalCount}'
                    : 'Evidencia',
                style: SaoTypography.sectionTitle.copyWith(fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _lensEnabled ? Icons.zoom_out_map_rounded : Icons.zoom_in_rounded,
                ),
                onPressed: () {
                  setState(() => _lensEnabled = !_lensEnabled);
                },
                tooltip: _lensEnabled ? 'Desactivar lupa' : 'Activar lupa',
              ),
              
              // Controles de navegación
              if (widget.onPrevious != null)
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded),
                  onPressed: widget.currentIndex != null && widget.currentIndex! > 0
                      ? widget.onPrevious
                      : null,
                  tooltip: 'Anterior (←)',
                ),
              if (widget.onNext != null)
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded),
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
              final lensSize = 140.0;
              final lensZoom = 2.2;
                final maxX = math.max(0.0, constraints.maxWidth - lensSize);
                final maxY = math.max(0.0, constraints.maxHeight - lensSize);
                final safeX = (_lensPosition.dx - lensSize / 2)
                  .clamp(0.0, maxX);
                final safeY = (_lensPosition.dy - lensSize / 2)
                  .clamp(0.0, maxY);

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
                      child: GestureDetector(
                        onPanUpdate: _handlePanUpdate,
                        child: Container(
                          color: SaoColors.gray100,
                          child: Center(
                            child: Transform.translate(
                              offset: _offset,
                              child: Transform.rotate(
                                angle: _rotationDegrees * 3.14159 / 180,
                                child: Transform.scale(
                                  scale: _scale,
                                  child: widget.imageUrl.startsWith('asset:')
                                      ? Image.asset(
                                          widget.imageUrl.replaceFirst('asset:', ''),
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildErrorWidget();
                                          },
                                        )
                                      : Image.network(
                                          widget.imageUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildErrorWidget();
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                        loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                        ),
                                ),
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
                              child: Image.network(
                                widget.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: EdgeInsets.all(SaoSpacing.sm),
                      decoration: BoxDecoration(
                        color: SaoColors.gray900.withOpacity(0.7),
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
                          if (widget.latitude != null && widget.longitude != null)
                            Text(
                              _formattedCoordinates,
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
          padding: EdgeInsets.symmetric(
            horizontal: SaoSpacing.md,
            vertical: SaoSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: SaoColors.surface,
            border: Border(top: BorderSide(color: SaoColors.border)),
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
              SizedBox(width: SaoSpacing.sm),
              Icon(Icons.info_outline, size: 12, color: SaoColors.gray500),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botón de herramienta flotante
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: Colors.white,
        onPressed: onPressed,
        disabledColor: Colors.white.withOpacity(0.3),
      ),
    );
  }
}
