// lib/ui/widgets/sao_chip.dart
import 'package:flutter/material.dart';

/// Chip reutilizable de SAO
/// Uso: SaoChip(label: '...', selected: true/false)
class SaoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const SaoChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: icon == null ? null : Icon(icon, size: 16),
      onSelected: onTap == null ? null : (_) => onTap!.call(),
    );
  }
}
