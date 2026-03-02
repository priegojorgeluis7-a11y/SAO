import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/application/auth_providers.dart';

class TutorialModePage extends ConsumerWidget {
  const TutorialModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    void goToOperation() {
      if (isAuthenticated) {
        ref.read(authControllerProvider.notifier).setTutorialMode(false);
        context.go('/');
        return;
      }
      context.go('/login');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo tutorial'),
        actions: [
          TextButton.icon(
            onPressed: goToOperation,
            icon: const Icon(Icons.play_arrow),
            label: Text(isAuthenticated ? 'Ir a operar' : 'Ir a login'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido${user == null ? '' : ', ${user.fullName}'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta guía rápida te explica cómo funciona el flujo de trabajo en campo dentro de SAO.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _StepCard(
            number: '1',
            title: 'Revisa actividades asignadas',
            description:
                'En Inicio verás actividades por frente/proyecto. Cada una inicia en estado Pendiente.',
            icon: Icons.assignment_outlined,
          ),
          const _StepCard(
            number: '2',
            title: 'Inicia y ejecuta actividad',
            description:
                'Haz swipe derecho para iniciar (se registra hora y ubicación). El estado cambia a En curso.',
            icon: Icons.play_circle_outline,
          ),
          const _StepCard(
            number: '3',
            title: 'Termina y captura',
            description:
                'Vuelve a hacer swipe derecho para terminar y abrir el wizard: contexto, clasificación, evidencias y confirmación.',
            icon: Icons.rule_folder_outlined,
          ),
          const _StepCard(
            number: '4',
            title: 'Guarda y sincroniza',
            description:
                'Al guardar, la actividad queda local y entra al flujo de sincronización. Si estás offline, la cola se reintenta luego.',
            icon: Icons.sync_outlined,
          ),
          const _StepCard(
            number: '5',
            title: 'Si cancelas',
            description:
                'Si cierras sin guardar, la actividad permanece en Revisión pendiente para reabrir y completar más tarde.',
            icon: Icons.warning_amber_outlined,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explora vistas reales de la app',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Estas opciones abren las pantallas reales en modo tutorial (sin login).',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.go('/?tutorial=1'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Inicio'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/sync?tutorial=1'),
                        icon: const Icon(Icons.sync_outlined),
                        label: const Text('Sincronización'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/agenda?tutorial=1'),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: const Text('Agenda'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/settings?tutorial=1'),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Ajustes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: goToOperation,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: Text(
              isAuthenticated ? 'Comenzar operación real' : 'Ir a iniciar sesión',
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(number),
        ),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description),
        ),
        trailing: Icon(icon),
      ),
    );
  }
}
