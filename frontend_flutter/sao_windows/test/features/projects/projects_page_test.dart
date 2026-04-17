import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sao_windows/data/repositories/projects_repository.dart';
import 'package:sao_windows/features/projects/projects_page.dart';

void main() {
  testWidgets(
    'opening ProjectsPage with an initial selection does not throw provider build errors',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allProjectsProvider.overrideWith(
              (ref) async => const [
                ProjectDto(
                  id: '1',
                  code: 'TMQ',
                  name: 'Tren México–Querétaro',
                  isActive: true,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: ProjectsPage(selectedCode: 'TMQ'),
          ),
        ),
      );

      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'The project selector must not mutate Riverpod state during build.',
      );

      expect(find.text('Proyectos'), findsOneWidget);
      expect(find.text('TMQ'), findsWidgets);
    },
  );
}
