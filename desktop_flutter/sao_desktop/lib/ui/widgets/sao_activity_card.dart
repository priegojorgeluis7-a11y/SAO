// lib/ui/widgets/sao_activity_card.dart
import 'package:flutter/material.dart';
import '../../catalog/risk_catalog.dart';
import '../../catalog/status_catalog.dart';
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
    this.riskHeaderText,
    this.riskHeaderBackgroundColor,
    this.activityCode,
    this.railwayPkRange,
    this.socialLocation,
    this.descriptionText,
    this.activityMain,
    this.subcategory,
    this.operationalStatus,
    this.responsible,
    this.riskChipText,
    this.folioText,
    this.pkText,
    this.stateMunicipalityText,
    this.activityText,
    this.subtypeText,
    this.purposeText,
    this.resultText,
    this.risk,
    this.status,
    this.activityLabel,
    this.subcategoryLabel,
    this.locationLabel,
    this.pkValueLabel,
    this.locationValueLabel,
    this.resultValueLabel,
    this.relativeTime,
    this.actorName,
    this.isNew = false,
    this.hasEvidence = false,
    this.evidenceIncreased = false,
    this.hasMissingRequired = false,
    this.syncIndicatorText,
    this.updatedAt,
    this.statusChipText,
    this.statusChipColor,
    this.statusChipBackground,
    this.compact = true,
    this.highlightPriority = false,
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
  final String? riskHeaderText;
  final Color? riskHeaderBackgroundColor;
  final String? activityCode;
  final String? railwayPkRange;
  final String? socialLocation;
  final String? descriptionText;
  final String? activityMain;
  final String? subcategory;
  final String? operationalStatus;
  final String? responsible;
  final String? riskChipText;
  final String? folioText;
  final String? pkText;
  final String? stateMunicipalityText;
  final String? activityText;
  final String? subtypeText;
  final String? purposeText;
  final String? resultText;
  final RiskLevel? risk;
  final StatusType? status;
  final String? activityLabel;
  final String? subcategoryLabel;
  final String? locationLabel;
  final String? pkValueLabel;
  final String? locationValueLabel;
  final String? resultValueLabel;
  final String? relativeTime;
  final String? actorName;
  final bool isNew;
  final bool hasEvidence;
  final bool evidenceIncreased;
  final bool hasMissingRequired;
  final String? syncIndicatorText;
  final DateTime? updatedAt;
  final String? statusChipText;
  final Color? statusChipColor;
  final Color? statusChipBackground;
  final bool compact;
  final bool highlightPriority;
  final VoidCallback? onTap;

  bool get _useRailwayLayout =>
      riskHeaderText != null ||
      railwayPkRange != null ||
      socialLocation != null ||
      responsible != null;

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      enabled: onTap != null,
      builder: (isHover) {
        final compactStatus =
            status ?? StatusCatalog.findByLabel(statusChipText ?? statusText) ?? StatusCatalog.enRevision;

        return Padding(
          padding: const EdgeInsets.only(bottom: SaoSpacing.md),
          child: Material(
            color: SaoColors.surfaceFor(context),
            borderRadius: BorderRadius.circular(14),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (!compact) return null;
                if (states.contains(WidgetState.pressed)) {
                  return compactStatus.color.withOpacity(0.10);
                }
                return null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: compact
                      ? Border.all(color: compactStatus.color, width: 1.5)
                      : Border.all(
                          color: (risk?.color ?? accentColor).withValues(alpha: 0.26),
                          width: 1.2,
                        ),
                  boxShadow: compact
                      ? [
                          BoxShadow(
                            blurRadius: isHover ? 12 : 8,
                            offset: const Offset(0, 3),
                            color: SaoColors.gray900.withOpacity(isHover ? 0.08 : 0.05),
                          ),
                        ]
                      : [
                          BoxShadow(
                            blurRadius: isHover ? 14 : 10,
                            offset: const Offset(0, 4),
                            color: needsAttention
                                ? SaoColors.warning.withOpacity(0.1)
                                : SaoColors.gray900.withOpacity(isHover ? 0.06 : 0.04),
                          ),
                        ],
                  color: compact
                          ? SaoColors.surfaceFor(context)
                      : isHover && !isSelected
                            ? SaoColors.surfaceMutedFor(context)
                          : isSelected
                              ? SaoColors.primary.withValues(alpha: 0.06)
                              : SaoColors.surfaceFor(context),
                ),
                child: compact
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            decoration: BoxDecoration(
                              color: compactStatus.color,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _buildCompactLayout(context),
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: _useRailwayLayout
                          ? _buildRailwayLayout(context)
                          : _buildDefaultLayout(context),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    final resolvedRisk =
        risk ?? RiskCatalog.findById((riskChipText ?? '').toLowerCase()) ?? RiskCatalog.medio;
    final resolvedStatus =
        status ?? StatusCatalog.findByLabel(statusChipText ?? statusText) ?? StatusCatalog.enRevision;
    final resolvedActivity = (activityLabel ?? activityText ?? activityMain ?? title).trim();
    final resolvedSubcategory = (subcategoryLabel ?? subtypeText ?? subcategory)?.trim();
    final resolvedPk =
        (pkLabel ?? pkValueLabel ?? pkText ?? railwayPkRange ?? '').trim();
    final resolvedLocation =
      (locationLabel ?? locationValueLabel ?? stateMunicipalityText ?? location ?? 'Sin ubicación').trim();
    final resolvedRelativeTime = (relativeTime ?? _relativeTime(updatedAt)).trim();
    final resolvedActor = (actorName ?? responsible ?? 'Sin responsable').trim();

    final safeActivity = resolvedActivity.isEmpty ? 'Actividad sin título' : resolvedActivity;
    final safeLocation = resolvedLocation.isEmpty ? 'Sin ubicación' : resolvedLocation;
    final safeRelativeTime = resolvedRelativeTime.isEmpty ? 'Sin hora' : resolvedRelativeTime;
    final safeActor = resolvedActor.isEmpty ? 'Sin responsable' : resolvedActor;

    final titleText =
        (resolvedSubcategory != null && resolvedSubcategory.isNotEmpty)
            ? '$safeActivity – $resolvedSubcategory'
            : safeActivity;

    final normalizedPkLabel = resolvedPk.isEmpty
        ? 'PK NO REGISTRADO'
        : (resolvedPk.toUpperCase().startsWith('PK')
            ? resolvedPk.toUpperCase()
            : 'PK ${resolvedPk.toUpperCase()}');
    final pkNotRegistered = normalizedPkLabel.contains('NO REGISTRADO');

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: resolvedRisk.backgroundColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${resolvedRisk.emoji} ${resolvedRisk.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SaoTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: resolvedRisk.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  safeRelativeTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: SaoTypography.caption.copyWith(
                    fontSize: 11,
                    color: SaoColors.gray600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: SaoColors.gray900,
                ) ??
                SaoTypography.bodyTextBold,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pkNotRegistered
                      ? SaoColors.alertBg
                      : SaoColors.surfaceRaisedFor(context).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: resolvedStatus.color.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  normalizedPkLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaoTypography.caption.copyWith(
                    color: pkNotRegistered ? SaoColors.alertText : SaoColors.gray800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  safeLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.gray800,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(resolvedStatus.icon, size: 16, color: resolvedStatus.color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  resolvedStatus.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaoTypography.caption.copyWith(
                    color: resolvedStatus.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Realizó: $safeActor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: SaoTypography.caption.copyWith(
                fontSize: 11,
                color: SaoColors.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime? when) {
    if (when == null) return 'sin registro';
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }

  Widget _buildDefaultLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  color: SaoColors.surfaceRaisedFor(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SaoColors.borderFor(context)),
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
        if (location != null)
          Text(
            location!,
            style: SaoTypography.caption.copyWith(
              fontSize: 13,
              color: SaoColors.gray600,
            ),
          ),
        const SizedBox(height: 10),
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
            Icon(
              Icons.chevron_right_rounded,
              color: SaoColors.gray400,
              size: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRailwayLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (riskHeaderText != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: SaoSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: SaoSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: riskHeaderBackgroundColor ?? accentColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(SaoRadii.sm),
            ),
            child: Text(
              riskHeaderText!,
              style: SaoTypography.bodyTextBold.copyWith(
                color: accentColor,
                fontSize: 12,
              ),
            ),
          ),
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
            if (activityCode != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SaoColors.surfaceRaisedFor(context),
                  borderRadius: BorderRadius.circular(SaoRadii.sm),
                  border: Border.all(color: SaoColors.borderFor(context)),
                ),
                child: Text(
                  activityCode!,
                  style: SaoTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SaoColors.gray700,
                  ),
                ),
              ),
          ],
        ),
        if (railwayPkRange != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('🛤️'),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  railwayPkRange!,
                  style: SaoTypography.bodyTextBold.copyWith(
                    color: SaoColors.gray800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (socialLocation != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('📍'),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  socialLocation!,
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.gray700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (activityMain != null || subcategory != null || operationalStatus != null) ...[
          const SizedBox(height: 6),
          Text(
            '${activityMain ?? 'Actividad'} · ${subcategory ?? 'Sin subcategoría'} · ${operationalStatus ?? statusText}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SaoTypography.caption.copyWith(
              color: SaoColors.gray700,
              fontSize: 12,
            ),
          ),
        ],
        if (descriptionText != null && descriptionText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '📝 $descriptionText',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SaoTypography.caption.copyWith(
              color: SaoColors.gray600,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
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
            if (responsible != null && responsible!.isNotEmpty)
              Text(
                '👤 $responsible',
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.gray600,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ],
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
      builder: (_, __) {
        final opacity = widget.isActive ? _animation.value : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 5,
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
