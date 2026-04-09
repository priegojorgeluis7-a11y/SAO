import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/auth/application/auth_providers.dart';
import 'package:sao_windows/features/auth/data/models/user.dart' as auth;
import 'package:sao_windows/features/profile/profile_stats_provider.dart';

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

  test('profile stats count directly assigned synced activities even when agenda row is unassigned', () async {
    final db = AppDb();
    getIt.registerSingleton<AppDb>(db);
    final now = DateTime.now();

    await db.into(db.roles).insertOnConflictUpdate(
          const RolesCompanion(
            id: drift.Value(4),
            name: drift.Value('Operativo'),
          ),
        );
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: 'user-1',
            name: 'Usuario Operativo',
            roleId: 4,
          ),
        );
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: 'user-2',
            name: 'Supervisor',
            roleId: 4,
          ),
        );
    await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            id: 'TMQ',
            code: 'TMQ',
            name: 'Tren Mexico Queretaro',
            isActive: const drift.Value(true),
          ),
        );
    await db.into(db.catalogActivityTypes).insert(
          CatalogActivityTypesCompanion.insert(
            id: 'unknown_activity_type',
            code: 'UNKNOWN_ACTIVITY_TYPE',
            name: 'Actividad desconocida',
            requiresPk: const drift.Value(false),
            requiresGeo: const drift.Value(false),
            requiresMinuta: const drift.Value(false),
            requiresEvidence: const drift.Value(false),
            isActive: const drift.Value(true),
            catalogVersion: const drift.Value(1),
          ),
        );

    await db.batch((batch) {
      batch.insertAll(
        db.activities,
        [
          ActivitiesCompanion.insert(
            id: 'act-created',
            projectId: 'TMQ',
            activityTypeId: 'unknown_activity_type',
            title: 'Creada por operativo',
            createdAt: now,
            createdByUserId: 'user-1',
            status: const drift.Value('SYNCED'),
          ),
          ActivitiesCompanion.insert(
            id: 'act-assigned',
            projectId: 'TMQ',
            activityTypeId: 'unknown_activity_type',
            title: 'Asignada desde backend',
            createdAt: now,
            createdByUserId: 'user-2',
            assignedToUserId: const drift.Value('user-1'),
            status: const drift.Value('SYNCED'),
          ),
        ],
      );

      batch.insert(
        db.agendaAssignments,
        AgendaAssignmentsCompanion.insert(
          id: 'asg-1',
          projectId: 'TMQ',
          resourceId: 'unassigned',
          activityId: const drift.Value('act-assigned'),
          title: 'Asignada desde backend',
          frente: const drift.Value('Frente A'),
          municipio: const drift.Value('Toluca'),
          estado: const drift.Value('EDOMEX'),
          pk: const drift.Value(150000),
          startAt: now,
          endAt: now.add(const Duration(hours: 1)),
          syncStatus: const drift.Value('synced'),
        ),
      );
    });

    final container = ProviderContainer(
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
    );
    addTearDown(container.dispose);

    final notifier = container.read(profileStatsProvider.notifier);
    await notifier.loadStats();

    final stats = container.read(profileStatsProvider);
    expect(stats.totalActivities, 2);
    expect(stats.syncedActivities, 2);
    expect(stats.completedActivities, 0);
    expect(stats.draftActivities, 0);
  });
}
