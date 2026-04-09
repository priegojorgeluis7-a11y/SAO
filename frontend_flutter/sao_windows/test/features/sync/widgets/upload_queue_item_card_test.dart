import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/sync/models/sync_models.dart';
import 'package:sao_windows/features/sync/widgets/upload_queue_item_card.dart';

UploadQueueItem _errorItem({
  required String id,
  required bool retryable,
  String? suggestedAction,
}) {
  return UploadQueueItem(
    id: id,
    entityId: 'entity-$id',
    entity: 'activity',
    type: UploadItemType.activity,
    title: 'Actividad $id',
    subtitle: 'TMQ',
    status: UploadItemStatus.error,
    errorMessage: 'VALIDATION_ERROR',
    retryable: retryable,
    suggestedAction: suggestedAction,
    createdAt: DateTime(2026, 3, 24, 8),
  );
}

void main() {
  testWidgets('shows suggested action for error items', (tester) async {
    final item = _errorItem(
      id: '1',
      retryable: true,
      suggestedAction: 'Completa el checklist antes de reenviar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UploadQueueItemCard(
            item: item,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('Actividad 1'), findsOneWidget);
    expect(find.text('VALIDATION_ERROR'), findsOneWidget);
    expect(
      find.text('Accion sugerida: Completa el checklist antes de reenviar'),
      findsOneWidget,
    );
  });

  testWidgets('renders non-retryable errors with disabled retry control', (tester) async {
    final item = _errorItem(
      id: '2',
      retryable: false,
      suggestedAction: 'Contacta soporte para revisar permisos',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UploadQueueItemCard(item: item),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    expect(button.tooltip, 'No reintentable');
    expect(find.byIcon(Icons.sync_disabled_rounded), findsOneWidget);
  });
}