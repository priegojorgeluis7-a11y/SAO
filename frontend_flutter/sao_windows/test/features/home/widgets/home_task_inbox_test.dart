import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/home/home_task_sections.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';
import 'package:sao_windows/features/home/widgets/home_task_inbox.dart';
import 'package:sao_windows/ui/theme/sao_colors.dart';

TodayActivity _activity({
  required String id,
  required String frente,
  required String nextAction,
}) {
  return TodayActivity(
    id: id,
    title: 'Actividad $id',
    frente: frente,
    municipio: 'Toluca',
    estado: 'EDOMEX',
    status: ActivityStatus.hoy,
    createdAt: DateTime(2026, 3, 24, 8),
    nextAction: nextAction,
  );
}

void main() {
  testWidgets('renders inbox sections and grouped content in expected order', (tester) async {
    final sections = buildHomeTaskSections([
      _activity(id: '1', frente: 'Frente A', nextAction: 'INICIAR_ACTIVIDAD'),
      _activity(id: '2', frente: 'Frente B', nextAction: 'CORREGIR_Y_REENVIAR'),
      _activity(id: '3', frente: 'Frente A', nextAction: 'TERMINAR_ACTIVIDAD'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeTaskInboxList(
              sections: sections,
              colorForSection: (_) => SaoColors.primary,
              iconForSection: (_) => Icons.inbox_rounded,
              childrenBuilder: (_, section) {
                return section.groupedByFrente.entries
                    .map(
                      (entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frente: ${entry.key}'),
                          ...entry.value.map((item) => Text(item.title)),
                        ],
                      ),
                    )
                    .toList();
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Por iniciar'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('Por corregir'), findsOneWidget);

    expect(find.text('Frente: Frente A'), findsNWidgets(2));
    expect(find.text('Frente: Frente B'), findsOneWidget);
    expect(find.text('Actividad 1'), findsOneWidget);
    expect(find.text('Actividad 2'), findsOneWidget);
    expect(find.text('Actividad 3'), findsOneWidget);

    final porIniciar = tester.getTopLeft(find.text('Por iniciar')).dy;
    final enCurso = tester.getTopLeft(find.text('En curso')).dy;
    final porCorregir = tester.getTopLeft(find.text('Por corregir')).dy;

    expect(porCorregir, lessThan(porIniciar));
    expect(porIniciar, lessThan(enCurso));
  });
}