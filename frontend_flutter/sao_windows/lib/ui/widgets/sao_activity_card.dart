// lib/ui/widgets/sao_activity_card.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_typography.dart';

/// Tarjeta de Actividad UNIFICADA (compartida mobile + desktop)
/// 
/// Esta tarjeta es idéntica en ambas plataformas y sigue el diseño de la app móvil:
/// - Barra vertical de color por riesgo/estado (con animación opcional)
/// - Título prominente + PK badge
/// - Metadatos: Frente, Municipio/Estado
/// - Footer con icono y texto de estado
/// - Hover sutil en desktop
/// - Estados: normal, selected, attention (necesita acción)
class SaoActivityCard extends StatelessWidget {
  const SaoActivityCard({
    super.key,
    required this.title,
    this.pkLabel,
    this.subtitle,
    this.location,
    required this.statusText,
    required this.statusIcon,
    required this.accentColor,
    this.badge,
    this.isSelected = false,
    this.needsAttention = false,
    this.isActive = false,
    this.onTap,
  });

  final String title;
  final String? pkLabel;       // e.g. "142+000"
  final String? subtitle;      // e.g. "Frente Norte"
  final String? location;      // e.g. "Querétaro, Apaseo el Grande"
  final String statusText;     // e.g. "En curso • Iniciada 14:30"
  final IconData statusIcon;   // e.g. Icons.play_circle_fill_rounded
  final Color accentColor;     // Color de la barra izquierda (riesgo/estado)
  final Widget? badge;         // Badge opcional superior derecha (e.g. "Pendiente")
  final bool isSelected;
  final bool needsAttention;   // Borde warning + badge "Pendiente"
  final bool isActive;         // Animación pulsante en barra
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      enabled: onTap != null,
      builder: (isHover) {
        return Padding(
          padding: const EdgeInsets.only(bottom: SaoSpacing.md),
          child: Material(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(SaoRadii.lg),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(SaoRadii.lg),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SaoRadii.lg),
                  border: Border.all(
                    color: needsAttention 
                        ? SaoColors.warning 
                        : isSelected 
                            ? SaoColors.borderStrong 
                            : SaoColors.border,
                    width: needsAttention ? 2 : 1,
                  ),
                  color: isHover && !isSelected 
                      ? SaoColors.gray50 
                      : isSelected 
                          ? SaoColors.primary.withOpacity(0.06) 
                          : SaoColors.surface,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: isHover ? 14 : 10,
                      offset: const Offset(0, 4),
                      color: needsAttention
                          ? SaoColors.warning.withOpacity(0.1)
                          : SaoColors.gray900.withOpacity(isHover ? 0.06 : 0.04),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Barra de acento (riesgo/estado) con animación opcional
                    _PulsingBar(
                      color: accentColor,
                      height: 96,
                      isActive: isActive || needsAttention,
                    ),
                    
                    // Contenido
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SaoSpacing.md,
                          SaoSpacing.md,
                          10,
                          SaoSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Título + PK + Badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: SaoTypography.cardTitle,
                                  ),
                                ),
                                if (badge != null) ...[
                                  const SizedBox(width: SaoSpacing.sm),
                                  badge!,
                                ],
                                if (pkLabel != null) ...[
                                  const SizedBox(width: SaoSpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SaoColors.gray100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: SaoColors.border),
                                    ),
                                    child: Text(
                                      pkLabel!,
                                      style: SaoTypography.mono,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            
                            const SizedBox(height: 6),
                            
                            // Subtitle (Frente)
                            if (subtitle != null) ...[
                              Text(
                                subtitle!,
                                style: SaoTypography.bodyTextBold.copyWith(
                                  fontSize: 13,
                                  color: SaoColors.gray700,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            
                            // Location (Municipio, Estado)
                            if (location != null)
                              Text(
                                location!,
                                style: SaoTypography.caption.copyWith(
                                  fontSize: 13,
                                  color: SaoColors.gray600,
                                ),
                              ),
                            
                            const SizedBox(height: 10),
                            
                            // Footer: Status icon + text + chevron
                            Row(
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 16,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    statusText,
                                    overflow: TextOverflow.ellipsis,
                                    style: SaoTypography.bodyTextBold.copyWith(
                                      fontSize: 12,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: SaoColors.gray400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Barra de acento con animación pulsante opcional
class _PulsingBar extends StatefulWidget {
  final Color color;
  final double height;
  final bool isActive;

  const _PulsingBar({
    required this.color,
    required this.height,
    required this.isActive,
  });

  @override
  State<_PulsingBar> createState() => _PulsingBarState();
}

class _PulsingBarState extends State<_PulsingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        final opacity = widget.isActive ? _animation.value : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(SaoRadii.lg),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wrapper para hover en desktop (no afecta mobile)
class _HoverCard extends StatefulWidget {
  const _HoverCard({
    required this.builder,
    required this.enabled,
  });

  final Widget Function(bool isHover) builder;
  final bool enabled;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hover = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hover = false) : null,
      child: widget.builder(_hover),
    );
  }
}
