// lib/ui/widgets/sao_panel.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_typography.dart';

/// Panel con header y body para layouts consistentes
class SaoPanel extends StatelessWidget {
  const SaoPanel({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding,
    this.headerPadding,
    this.showDivider = true,
    this.collapsible = false,
    this.initiallyCollapsed = false,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? headerPadding;
  final bool showDivider;
  final bool collapsible;
  final bool initiallyCollapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsible) {
      return _CollapsiblePanel(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        initiallyCollapsed: initiallyCollapsed,
        showDivider: showDivider,
        padding: padding,
        headerPadding: headerPadding,
        child: child,
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || trailing != null)
          _PanelHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            padding: headerPadding,
          ),
        if ((title != null || trailing != null) && showDivider)
          Divider(height: 1, color: SaoColors.borderFor(context)),
        Padding(
          padding: padding ??
              const EdgeInsets.all(SaoSpacing.lg),
          child: child,
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border.all(color: SaoColors.borderFor(context)),
        borderRadius: BorderRadius.circular(SaoRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(child: body),
    );
  }
}

/// Header interno del panel
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.all(SaoSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: SaoTypography.sectionTitle,
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: SaoSpacing.xs),
                  Text(
                    subtitle!,
                    style: SaoTypography.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SaoSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Panel colapsable
class _CollapsiblePanel extends StatefulWidget {
  const _CollapsiblePanel({
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding,
    this.headerPadding,
    this.showDivider = true,
    this.initiallyCollapsed = false,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? headerPadding;
  final bool showDivider;
  final bool initiallyCollapsed;

  @override
  State<_CollapsiblePanel> createState() => _CollapsiblePanelState();
}

class _CollapsiblePanelState extends State<_CollapsiblePanel> {
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initiallyCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border.all(color: SaoColors.borderFor(context)),
        borderRadius: BorderRadius.circular(SaoRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SaoRadii.lg - 1),
            ),
            child: Padding(
              padding: widget.headerPadding ??
                  const EdgeInsets.all(SaoSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    _isCollapsed
                        ? Icons.arrow_right
                        : Icons.arrow_drop_down,
                    color: SaoColors.textMutedFor(context),
                  ),
                  const SizedBox(width: SaoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title != null)
                          Text(
                            widget.title!,
                            style: SaoTypography.sectionTitle,
                          ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: SaoSpacing.xs),
                          Text(
                            widget.subtitle!,
                            style: SaoTypography.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: SaoSpacing.md),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
          if (!_isCollapsed) ...[
            if (widget.showDivider)
              Divider(height: 1, color: SaoColors.borderFor(context)),
            Padding(
              padding: widget.padding ??
                  const EdgeInsets.all(SaoSpacing.lg),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel expandible (toma todo el espacio disponible)
class SaoExpandedPanel extends StatelessWidget {
  const SaoExpandedPanel({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding,
    this.headerPadding,
    this.showDivider = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? headerPadding;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border.all(color: SaoColors.borderFor(context)),
        borderRadius: BorderRadius.circular(SaoRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null)
            _PanelHeader(
              title: title,
              subtitle: subtitle,
              trailing: trailing,
              padding: headerPadding,
            ),
          if ((title != null || trailing != null) && showDivider)
            Divider(height: 1, color: SaoColors.borderFor(context)),
          Expanded(
            child: Padding(
              padding: padding ??
                  const EdgeInsets.all(SaoSpacing.lg),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel simple sin header (solo contenedor estilizado)
class SaoSimplePanel extends StatelessWidget {
  const SaoSimplePanel({
    super.key,
    required this.child,
    this.padding,
    this.color,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(SaoSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? SaoColors.surfaceFor(context),
        border: Border.all(color: SaoColors.borderFor(context)),
        borderRadius: BorderRadius.circular(SaoRadii.lg),
      ),
      child: child,
    );
  }
}
