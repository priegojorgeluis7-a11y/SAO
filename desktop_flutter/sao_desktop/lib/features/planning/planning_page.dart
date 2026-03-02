import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../ui/theme/sao_colors.dart';

class PlanningPage extends StatelessWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_rounded, size: 64, color: SaoColors.gray400),
          const SizedBox(height: 16),
          Text(
            'Módulo de Planeación',
            style: TextStyle(fontSize: 18, color: SaoColors.gray600),
          ),
          const SizedBox(height: 8),
          Text(
            'Asignación de actividades y calendario',
            style: TextStyle(fontSize: 14, color: SaoColors.gray500),
          ),
        ],
      ),
    );
  }
}
