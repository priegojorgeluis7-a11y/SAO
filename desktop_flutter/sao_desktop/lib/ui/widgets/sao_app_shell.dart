// lib/ui/widgets/sao_app_shell.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_typography.dart';

/// Shell de aplicación base para SAO (Mobile + Desktop)
/// 
/// **Mobile**: AppBar + Body + FAB opcional
/// **Desktop**: TopBar + Body (columnas) + Footer opcional
/// 
/// Uso:
/// ```dart
/// SaoAppShell(
///   title: 'Torre de Control',
///   subtitle: 'Proyecto TMQ',
///   body: MyContent(),
///   actions: [IconButton(...)],
/// )
/// ```
class SaoAppShell extends StatelessWidget {
  const SaoAppShell({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    required this.body,
    this.footer,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget body;
  final Widget? footer;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Detectar si es desktop (ancho > 600)
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      return _DesktopShell(
        title: title,
        subtitle: subtitle,
        leading: leading,
        actions: actions,
        body: body,
        footer: footer,
        backgroundColor: backgroundColor,
      );
    }

    return _MobileShell(
      title: title,
      subtitle: subtitle,
      leading: leading,
      actions: actions,
      body: body,
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
    );
  }
}

/// Shell Mobile
class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? SaoColors.scaffoldBackgroundFor(context),
      appBar: AppBar(
        backgroundColor: SaoColors.surfaceFor(context),
        surfaceTintColor: SaoColors.surfaceFor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: leading,
        title: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SaoTypography.bodyTextBold.copyWith(fontSize: 15),
                  ),
                  Text(
                    subtitle!,
                    style: SaoTypography.caption.copyWith(fontSize: 12),
                  ),
                ],
              )
            : Text(
                title,
                style: SaoTypography.bodyTextBold.copyWith(fontSize: 16),
              ),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Shell Desktop (3 columnas o layout personalizado)
class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    required this.body,
    this.footer,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget body;
  final Widget? footer;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? SaoColors.scaffoldBackgroundFor(context),
      body: Column(
        children: [
          // TopBar
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: SaoColors.surfaceFor(context),
              border: Border(
                bottom: BorderSide(color: SaoColors.borderFor(context)),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: SaoSpacing.xxl,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: SaoSpacing.lg),
                ],
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SaoTypography.pageTitle.copyWith(fontSize: 18),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: SaoTypography.caption,
                      ),
                  ],
                ),
                const Spacer(),
                if (actions != null) ...actions!,
              ],
            ),
          ),

          // Body
          Expanded(child: body),

          // Footer (opcional)
          if (footer != null)
            Container(
              decoration: BoxDecoration(
                color: SaoColors.surfaceFor(context),
                border: Border(
                  top: BorderSide(color: SaoColors.borderFor(context)),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.xxl,
                vertical: SaoSpacing.lg,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}
