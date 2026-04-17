import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/agenda/models/agenda_item.dart';
import 'package:sao_windows/features/agenda/models/resource.dart';
import 'package:sao_windows/features/agenda/widgets/agenda_mini_card.dart';
import 'package:sao_windows/features/agenda/widgets/timeline_list.dart';

void main() {
  testWidgets('shows transfer action in agenda detail sheet when enabled', (
    tester,
  ) async {
    final item = AgendaItem(
      id: 'assignment-1',
      resourceId: 'user-1',
      title: 'Inspección',
      projectCode: 'TMQ',
      frente: 'Frente A',
      municipio: 'Toluca',
      estado: 'EDOMEX',
      start: DateTime(2026, 4, 16, 9),
      end: DateTime(2026, 4, 16, 10),
      nextAction: 'INICIAR_ACTIVIDAD',
    );

    const resource = Resource(
      id: 'user-1',
      name: 'Operativo Uno',
      role: ResourceRole.tecnico,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineList(
            items: [item],
            resources: const [resource],
            startHour: 9,
            endHour: 10,
            onTransferItem: (_) async {},
            canTransferItem: (_) => true,
          ),
        ),
      ),
    );

    final card = find.byType(AgendaMiniCard).first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Transferir'), findsOneWidget);
  });
}
