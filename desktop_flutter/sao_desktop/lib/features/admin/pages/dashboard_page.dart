import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Panel Admin SAO\n\nUsa la barra lateral para gestionar proyectos, usuarios y auditoría.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
