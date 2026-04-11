// lib/ui/widgets/special/sao_project_switcher.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_typography.dart';
import '../../theme/sao_spacing.dart';
import '../../theme/sao_radii.dart';

/// Selector visual de proyecto con logo/color
/// 
/// Permite cambiar entre proyectos ferroviarios (TMQ, TAP, TSNL, etc.)
/// con representación visual distintiva por proyecto.
class SaoProjectSwitcher extends StatelessWidget {
  final String currentProject;
  final List<ProjectItem> projects;
  final ValueChanged<String> onProjectChanged;

  const SaoProjectSwitcher({
    super.key,
    required this.currentProject,
    required this.projects,
    required this.onProjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Implementar dropdown con logos y colores por proyecto
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SaoSpacing.md,
        vertical: SaoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border.all(color: SaoColors.borderFor(context)),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Text(
        'Project Switcher (TODO)',
        style: SaoTypography.projectTitle,
      ),
    );
  }
}

/// Modelo de proyecto
class ProjectItem {
  final String id;
  final String name;
  final String shortName;
  final Color color;
  final IconData icon;

  const ProjectItem({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    required this.icon,
  });
}
