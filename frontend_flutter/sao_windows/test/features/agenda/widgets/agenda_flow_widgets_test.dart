import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/agenda/models/agenda_item.dart';
import 'package:sao_windows/features/agenda/models/resource.dart';
import 'package:sao_windows/features/agenda/widgets/agenda_mini_card.dart';
import 'package:sao_windows/features/agenda/widgets/timeline_list.dart';

AgendaItem _agendaItem({
  required String id,
  required String nextAction,
  SyncStatus syncStatus = SyncStatus.pending,
}) {
  return AgendaItem(
    id: id,
    resourceId: 'res-1',
    title: 'Inspeccion $id',
    projectCode: 'TMQ',
    frente: 'Frente Norte',
    municipio: 'Toluca',
    estado: 'EDOMEX',
    pk: 142000,
    start: DateTime(2026, 3, 24, 8, 0),
    end: DateTime(2026, 3, 24, 9, 0),
    nextAction: nextAction,
    syncStatus: syncStatus,
  );
}

const _resource = Resource(
  id: 'res-1',
  name: 'Juan Perez',
  role: ResourceRole.tecnico,
  isActive: true,
);

void main() {
  testWidgets('AgendaMiniCard shows the next action label', (tester) async {
    final item = _agendaItem(id: 'A1', nextAction: 'CORREGIR_Y_REENVIAR');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgendaMiniCard(
            item: item,
            resource: _resource,
          ),
        ),
      ),
    );

    expect(find.text('Inspeccion A1'), findsOneWidget);
    expect(find.text('PK 142+000'), findsOneWidget);
    expect(find.text('Corregir y reenviar'), findsOneWidget);
  });

  testWidgets('TimelineList detail sheet shows the next action label', (tester) async {
    final item = _agendaItem(id: 'A2', nextAction: 'ESPERAR_DECISION_COORDINACION');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineList(
            items: [item],
            resources: const [_resource],
            startHour: 8,
            endHour: 10,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Inspeccion A2'));
    await tester.pumpAndSettle();

    expect(find.text('Esperando revision'), findsWidgets);
    expect(find.text('Juan Perez'), findsOneWidget);
    expect(find.text('08:00 - 09:00'), findsWidgets);
  });

  testWidgets('approved agenda items open the activity directly on tap', (tester) async {
    final item = _agendaItem(id: 'A3', nextAction: 'CERRADA_APROBADA');
    AgendaItem? openedItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineList(
            items: [item],
            resources: const [_resource],
            startHour: 8,
            endHour: 10,
            onOpenItem: (agendaItem) async {
              openedItem = agendaItem;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Inspeccion A3'));
    await tester.pumpAndSettle();

    expect(openedItem?.id, 'A3');
    expect(find.text('Juan Perez'), findsNothing);
    expect(find.text('Terminada'), findsOneWidget);
  });

  testWidgets('TimelineList exposes a visible transfer action on agenda cards', (tester) async {
    final item = _agendaItem(id: 'A4', nextAction: 'INICIAR_ACTIVIDAD');
    AgendaItem? transferredItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineList(
            items: [item],
            resources: const [_resource],
            startHour: 8,
            endHour: 10,
            onTransferItem: (agendaItem) async {
              transferredItem = agendaItem;
            },
            canTransferItem: (_) => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pumpAndSettle();

    expect(transferredItem?.id, 'A4');
  });

  testWidgets('TimelineList shows the extended schedule until 23:00', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineList(
            items: [],
            resources: [_resource],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('23:00'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('23:00'), findsOneWidget);
  });
}