import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../ui/theme/sao_colors.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_rounded, size: 64, color: SaoColors.gray400),
          const SizedBox(height: 16),
          Text(
            'Módulo de Usuarios',
            style: TextStyle(fontSize: 18, color: SaoColors.gray600),
          ),
          const SizedBox(height: 8),
          Text(
            'Administración de usuarios y permisos',
            style: TextStyle(fontSize: 14, color: SaoColors.gray500),
          ),
        ],
      ),
    );
  }
}
