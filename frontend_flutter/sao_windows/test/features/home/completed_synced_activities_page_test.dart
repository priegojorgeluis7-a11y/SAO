import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/auth/application/auth_providers.dart';
import 'package:sao_windows/features/auth/data/models/user.dart' as auth;
import 'package:sao_windows/features/home/completed_synced_activities_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final getIt = GetIt.I;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp.createTempSync('sao_windows_test').path;
          }
          return null;
        });
  });

  tearDown(() async {
    if (getIt.isRegistered<AppDb>()) {
      final db = getIt<AppDb>();
      getIt.unregister<AppDb>();
      await db.close();
    }
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'history shows synced assigned activities with their current state',
    (tester) async {
      final db = AppDb();
      getIt.registerSingleton<AppDb>(db);
      final now = DateTime.now();

      await db
          .into(db.roles)
          .insertOnConflictUpdate(
            const RolesCompanion(
              id: drift.Value(4),
              name: drift.Value('Operativo'),
            ),
          );
      await db
          .into(db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: 'user-1',
              name: 'Usuario Operativo',
              roleId: 4,
            ),
          );
      await db
          .into(db.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await db
          .into(db.catalogActivityTypes)
          .insertOnConflictUpdate(
            CatalogActivityTypesCompanion.insert(
              id: 'unknown_activity_type',
              code: 'UNKNOWN_ACTIVITY_TYPE',
              name: 'Actividad sincronizada visible',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(false),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );

      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-sync-visible',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad sincronizada visible',
              createdAt: now,
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('SYNCED'),
              startedAt: drift.Value(now),
            ),
          );

      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-sync-visible:operational_state',
              activityId: 'act-sync-visible',
              fieldKey: 'operational_state',
              valueText: const drift.Value('EN_CURSO'),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => auth.User(
                id: 'user-1',
                email: 'user1@example.com',
                fullName: 'Usuario Operativo',
                status: 'active',
                createdAt: now,
              ),
            ),
          ],
          child: const MaterialApp(
            home: CompletedSyncedActivitiesPage(selectedProject: 'TMQ'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Actividad sincronizada visible'), findsOneWidget);
      expect(find.textContaining('En curso'), findsWidgets);
    },
  );

  testWidgets(
    'history deduplicates logical duplicates and keeps correction-required state',
    (tester) async {
      final db = AppDb();
      getIt.registerSingleton<AppDb>(db);
      final now = DateTime.now();

      await db
          .into(db.roles)
          .insertOnConflictUpdate(
            const RolesCompanion(
              id: drift.Value(4),
              name: drift.Value('Operativo'),
            ),
          );
      await db
          .into(db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: 'user-1',
              name: 'Usuario Operativo',
              roleId: 4,
            ),
          );
      await db
          .into(db.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await db
          .into(db.catalogActivityTypes)
          .insertOnConflictUpdate(
            CatalogActivityTypesCompanion.insert(
              id: 'unknown_activity_type',
              code: 'UNKNOWN_ACTIVITY_TYPE',
              name: 'Actividad duplicada',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(false),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );

      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-duplicate-pending',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad duplicada',
              createdAt: now,
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('SYNCED'),
              pk: const drift.Value(100),
            ),
          );
      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-duplicate-rejected',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad duplicada',
              createdAt: now.add(const Duration(minutes: 1)),
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('RECHAZADA'),
              pk: const drift.Value(100),
            ),
          );

      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-duplicate-pending:operational_state',
              activityId: 'act-duplicate-pending',
              fieldKey: 'operational_state',
              valueText: const drift.Value('PENDIENTE'),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-duplicate-rejected:review_state',
              activityId: 'act-duplicate-rejected',
              fieldKey: 'review_state',
              valueText: const drift.Value('CHANGES_REQUIRED'),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-duplicate-rejected:next_action',
              activityId: 'act-duplicate-rejected',
              fieldKey: 'next_action',
              valueText: const drift.Value('CORREGIR_Y_REENVIAR'),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => auth.User(
                id: 'user-1',
                email: 'user1@example.com',
                fullName: 'Usuario Operativo',
                status: 'active',
                createdAt: now,
              ),
            ),
          ],
          child: const MaterialApp(
            home: CompletedSyncedActivitiesPage(selectedProject: 'TMQ'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Actividad duplicada'), findsOneWidget);
      expect(find.text('Rechazada · Requiere correccion'), findsOneWidget);
      expect(find.text('Sincronizada · Pendiente'), findsNothing);
    },
  );

  testWidgets(
    'history keeps corrected pending-review activities visible even with pending evidence uploads',
    (tester) async {
      final db = AppDb();
      getIt.registerSingleton<AppDb>(db);
      final now = DateTime.now();

      await db
          .into(db.roles)
          .insertOnConflictUpdate(
            const RolesCompanion(
              id: drift.Value(4),
              name: drift.Value('Operativo'),
            ),
          );
      await db
          .into(db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: 'user-1',
              name: 'Usuario Operativo',
              roleId: 4,
            ),
          );
      await db
          .into(db.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await db
          .into(db.catalogActivityTypes)
          .insertOnConflictUpdate(
            CatalogActivityTypesCompanion.insert(
              id: 'unknown_activity_type',
              code: 'UNKNOWN_ACTIVITY_TYPE',
              name: 'Actividad corregida',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(true),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );

      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-pending-review-history',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad corregida',
              createdAt: now,
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('SYNCED'),
              startedAt: drift.Value(now.subtract(const Duration(hours: 1))),
              finishedAt: drift.Value(now),
              pk: const drift.Value(30),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-pending-review-history:review_state',
              activityId: 'act-pending-review-history',
              fieldKey: 'review_state',
              valueText: const drift.Value('PENDING_REVIEW'),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-pending-review-history:next_action',
              activityId: 'act-pending-review-history',
              fieldKey: 'next_action',
              valueText: const drift.Value('ESPERAR_DECISION_COORDINACION'),
            ),
          );
      await db
          .into(db.pendingUploads)
          .insert(
            PendingUploadsCompanion.insert(
              id: 'upload-1',
              activityId: 'act-pending-review-history',
              localPath: '/tmp/evidence.jpg',
              fileName: 'evidence.jpg',
              mimeType: 'image/jpeg',
              sizeBytes: 1234,
              status: const drift.Value('PENDING_INIT'),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => auth.User(
                id: 'user-1',
                email: 'user1@example.com',
                fullName: 'Usuario Operativo',
                status: 'active',
                createdAt: now,
              ),
            ),
          ],
          child: const MaterialApp(
            home: CompletedSyncedActivitiesPage(selectedProject: 'TMQ'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Actividad corregida'), findsOneWidget);
      expect(find.text('Sincronizada · En revision'), findsOneWidget);
    },
  );

  testWidgets(
    'history hides authored pending rows that are not assigned to the current user',
    (tester) async {
      final db = AppDb();
      getIt.registerSingleton<AppDb>(db);
      final now = DateTime.now();

      await db
          .into(db.roles)
          .insertOnConflictUpdate(
            const RolesCompanion(
              id: drift.Value(4),
              name: drift.Value('Operativo'),
            ),
          );
      await db
          .into(db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: 'creator-user',
              name: 'Usuario Operativo',
              roleId: 4,
            ),
          );
      await db
          .into(db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: 'someone-else',
              name: 'Otro Usuario',
              roleId: 4,
            ),
          );
      await db
          .into(db.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await db
          .into(db.catalogActivityTypes)
          .insertOnConflictUpdate(
            CatalogActivityTypesCompanion.insert(
              id: 'unknown_activity_type',
              code: 'UNKNOWN_ACTIVITY_TYPE',
              name: 'Actividad authored',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(false),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );

      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-pending-authored',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Reunion authored',
              createdAt: now,
              createdByUserId: 'creator-user',
              assignedToUserId: const drift.Value('someone-else'),
              status: const drift.Value('SYNCED'),
              pk: const drift.Value(10),
            ),
          );
      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-rejected-authored',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Reunion authored',
              createdAt: now.add(const Duration(minutes: 1)),
              createdByUserId: 'creator-user',
              assignedToUserId: const drift.Value('someone-else'),
              status: const drift.Value('RECHAZADA'),
              pk: const drift.Value(10),
            ),
          );

      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-pending-authored:operational_state',
              activityId: 'act-pending-authored',
              fieldKey: 'operational_state',
              valueText: const drift.Value('PENDIENTE'),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-rejected-authored:review_state',
              activityId: 'act-rejected-authored',
              fieldKey: 'review_state',
              valueText: const drift.Value('CHANGES_REQUIRED'),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-rejected-authored:next_action',
              activityId: 'act-rejected-authored',
              fieldKey: 'next_action',
              valueText: const drift.Value('CORREGIR_Y_REENVIAR'),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => auth.User(
                id: 'creator-user',
                email: 'creator@example.com',
                fullName: 'Usuario Operativo',
                status: 'active',
                createdAt: now,
              ),
            ),
          ],
          child: const MaterialApp(
            home: CompletedSyncedActivitiesPage(selectedProject: 'TMQ'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rechazada · Requiere correccion'), findsOneWidget);
      expect(find.text('Sincronizada · Pendiente'), findsNothing);
    },
  );

  testWidgets(
    'history hides never-started synced pending activities for the current user',
    (tester) async {
      final db = AppDb();
      getIt.registerSingleton<AppDb>(db);
      final now = DateTime.now();

      await db
          .into(db.roles)
          .insertOnConflictUpdate(
            const RolesCompanion(
              id: drift.Value(4),
              name: drift.Value('Operativo'),
            ),
          );
      await db
          .into(db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: 'user-1',
              name: 'Usuario Operativo',
              roleId: 4,
            ),
          );
      await db
          .into(db.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await db
          .into(db.catalogActivityTypes)
          .insertOnConflictUpdate(
            CatalogActivityTypesCompanion.insert(
              id: 'unknown_activity_type',
              code: 'UNKNOWN_ACTIVITY_TYPE',
              name: 'Actividad pendiente',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(false),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );

      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-pending-history',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad pendiente',
              createdAt: now,
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('SYNCED'),
              pk: const drift.Value(20),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-pending-history:operational_state',
              activityId: 'act-pending-history',
              fieldKey: 'operational_state',
              valueText: const drift.Value('PENDIENTE'),
            ),
          );
      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-pending-history:next_action',
              activityId: 'act-pending-history',
              fieldKey: 'next_action',
              valueText: const drift.Value('INICIAR_ACTIVIDAD'),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => auth.User(
                id: 'user-1',
                email: 'user1@example.com',
                fullName: 'Usuario Operativo',
                status: 'active',
                createdAt: now,
              ),
            ),
          ],
          child: const MaterialApp(
            home: CompletedSyncedActivitiesPage(selectedProject: 'TMQ'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Actividad pendiente'), findsNothing);
      expect(find.text('Sincronizada · Pendiente'), findsNothing);
    },
  );

  testWidgets(
    'history kpis allow quick filtering to correction-required activities',
    (tester) async {
      final db = AppDb();
      getIt.registerSingleton<AppDb>(db);
      final now = DateTime.now();

      await db
          .into(db.roles)
          .insertOnConflictUpdate(
            const RolesCompanion(
              id: drift.Value(4),
              name: drift.Value('Operativo'),
            ),
          );
      await db
          .into(db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: 'user-1',
              name: 'Usuario Operativo',
              roleId: 4,
            ),
          );
      await db
          .into(db.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await db
          .into(db.catalogActivityTypes)
          .insertOnConflictUpdate(
            CatalogActivityTypesCompanion.insert(
              id: 'activity_type_approved',
              code: 'APPROVED_ACTIVITY_TYPE',
              name: 'Actividad aprobada',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(false),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );
      await db
          .into(db.catalogActivityTypes)
          .insertOnConflictUpdate(
            CatalogActivityTypesCompanion.insert(
              id: 'activity_type_rejected',
              code: 'REJECTED_ACTIVITY_TYPE',
              name: 'Actividad rechazada',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(false),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );

      await db.into(db.activities).insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-approved',
              projectId: 'TMQ',
              activityTypeId: 'activity_type_approved',
              title: 'Actividad aprobada',
              createdAt: now,
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('SYNCED'),
              startedAt: drift.Value(now.subtract(const Duration(hours: 1))),
              finishedAt: drift.Value(now),
              pk: const drift.Value(111),
            ),
          );
      await db.into(db.activities).insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-rejected',
              projectId: 'TMQ',
              activityTypeId: 'activity_type_rejected',
              title: 'Actividad rechazada',
              createdAt: now.add(const Duration(minutes: 1)),
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('RECHAZADA'),
              pk: const drift.Value(222),
            ),
          );

      await db.into(db.activityFields).insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-approved:review_state',
              activityId: 'act-approved',
              fieldKey: 'review_state',
              valueText: const drift.Value('APPROVED'),
            ),
          );
      await db.into(db.activityFields).insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-approved:next_action',
              activityId: 'act-approved',
              fieldKey: 'next_action',
              valueText: const drift.Value('CERRADA_APROBADA'),
            ),
          );
      await db.into(db.activityFields).insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-rejected:review_state',
              activityId: 'act-rejected',
              fieldKey: 'review_state',
              valueText: const drift.Value('CHANGES_REQUIRED'),
            ),
          );
      await db.into(db.activityFields).insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-rejected:next_action',
              activityId: 'act-rejected',
              fieldKey: 'next_action',
              valueText: const drift.Value('CORREGIR_Y_REENVIAR'),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => auth.User(
                id: 'user-1',
                email: 'user1@example.com',
                fullName: 'Usuario Operativo',
                status: 'active',
                createdAt: now,
              ),
            ),
          ],
          child: const MaterialApp(
            home: CompletedSyncedActivitiesPage(selectedProject: 'TMQ'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('2 actividades visibles'), findsWidgets);
      expect(find.text('Por corregir'), findsOneWidget);

      await tester.tap(find.text('Por corregir'));
      await tester.pumpAndSettle();

      expect(find.text('Mostrando por corregir'), findsOneWidget);
      expect(find.text('Actividad rechazada'), findsOneWidget);
      expect(find.text('1 actividad visible'), findsWidgets);
    },
  );
}
