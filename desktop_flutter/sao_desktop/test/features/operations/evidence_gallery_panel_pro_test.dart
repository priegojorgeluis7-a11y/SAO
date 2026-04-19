import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/data/database/app_database.dart';
import 'package:sao_desktop/data/models/activity_model.dart';
import 'package:sao_desktop/data/repositories/evidence_repository.dart';
import 'package:sao_desktop/features/operations/widgets/evidence_gallery_panel_pro.dart';
import 'package:sao_desktop/ui/widgets/sao_evidence_viewer.dart';

class _DelayedEvidenceRepository extends EvidenceRepository {
  _DelayedEvidenceRepository(this.delay);

  final Duration delay;
  int callCount = 0;

  @override
  Future<String> getDownloadSignedUrl(String evidenceId) async {
    callCount += 1;
    await Future<void>.delayed(delay);
    return 'https://example.test/$evidenceId.pdf';
  }
}

ActivityWithDetails _buildActivityWithPendingEvidence({
  String? caption = 'Foto capturada en móvil',
  String? wizardDescription = 'Foto capturada en móvil',
}) {
  return ActivityWithDetails(
    activity: Activity(
      id: 'act-1',
      projectId: 'TMQ',
      activityTypeId: 'CAM',
      assignedTo: 'user-1',
      title: 'Actividad con evidencia pendiente',
      status: 'PENDING_REVIEW',
      createdAt: DateTime(2026, 4, 6, 17, 10),
    ),
    evidences: [
      Evidence(
        id: 'ev-1',
        activityId: 'act-1',
        filePath: 'pending://evidence/ev-1',
        fileType: 'IMAGE',
        caption: caption,
        capturedAt: DateTime(2026, 4, 6, 17, 10),
      ),
    ],
    wizardPayload: {
      'evidences': [
        {'id': 'ev-1', 'descripcion': wizardDescription}
      ],
    },
    flags: const ActivityFlags(checklistIncomplete: true),
  );
}

void main() {
  testWidgets(
    'shows a clear pending-sync message when the evidence file is not yet available',
    (tester) async {
      final activity = _buildActivityWithPendingEvidence();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 900,
              child: EvidenceGalleryPanelPro(
                activity: activity,
                selectedIndex: 0,
                onSelectEvidence: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('aún no está disponible en el servidor'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sincroniza nuevamente desde el móvil'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'falls back to the wizard footnote description when the evidence caption is missing',
    (tester) async {
      final activity = _buildActivityWithPendingEvidence(
        caption: null,
        wizardDescription: 'Pie desde móvil',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 900,
              child: EvidenceGalleryPanelPro(
                activity: activity,
                selectedIndex: 0,
                onSelectEvidence: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pie desde móvil'), findsWidgets);
      expect(find.text('Sin descripción'), findsNothing);
    },
  );

  testWidgets(
    'reuses the in-flight signed-url request while the backend evidence is loading',
    (tester) async {
      final repository = _DelayedEvidenceRepository(const Duration(seconds: 1));
      final activity = ActivityWithDetails(
        activity: Activity(
          id: 'act-2',
          projectId: 'TMQ',
          activityTypeId: 'CAM',
          assignedTo: 'user-2',
          title: 'Actividad con evidencia remota',
          status: 'PENDING_REVIEW',
          createdAt: DateTime(2026, 4, 6, 17, 30),
        ),
        evidences: [
          Evidence(
            id: 'ev-remote',
            activityId: 'act-2',
            filePath: 'backend://evidence/ev-remote',
            fileType: 'IMAGE',
            caption: 'Foto remota',
            capturedAt: DateTime(2026, 4, 6, 17, 30),
          ),
        ],
        flags: const ActivityFlags(),
      );

      Widget buildSubject() {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 900,
              child: EvidenceGalleryPanelPro(
                activity: activity,
                selectedIndex: 0,
                onSelectEvidence: (_) {},
                evidenceRepository: repository,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSubject());
      expect(find.textContaining('Cargando evidencia del servidor'),
          findsOneWidget);
      expect(repository.callCount, 1);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(buildSubject());
      expect(repository.callCount, 1);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'updates zoom controls in the shared evidence viewer',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 640,
              child: SaoEvidenceViewer(
                imageUrl: 'https://example.com/evidence.jpg',
                caption: 'Evidencia de prueba',
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Alejar'), findsOneWidget);
      expect(find.byTooltip('Acercar'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      await tester.tap(find.byTooltip('Acercar'));
      await tester.pump();
      expect(find.text('125%'), findsOneWidget);

      await tester.tap(find.byTooltip('Restablecer zoom'));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
    },
  );
}
