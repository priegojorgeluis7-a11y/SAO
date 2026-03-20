import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tables.dart';

part 'app_database.g.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Database must be overridden in main()');
});

@DriftDatabase(tables: [
  Users,
  Projects,
  ActivityTypes,
  Activities,
  Evidences,
  Assignments,
  Fronts,
  Municipalities,
  RejectionReasons,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(String path) : super(NativeDatabase(File(path)));

  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
      );

  Future<void> _seedInitialData() async {
    // Users
    await into(users).insert(UsersCompanion.insert(
      id: 'usr-admin-001',
      email: 'admin@sao.com',
      fullName: 'Admin Usuario',
      role: 'ADMIN',
      status: 'ACTIVE',
      createdAt: DateTime.now(),
    ));

    await into(users).insert(UsersCompanion.insert(
      id: 'usr-coord-001',
      email: 'coord@sao.com',
      fullName: 'Pedro Coordinador',
      role: 'COORDINATOR',
      status: 'ACTIVE',
      createdAt: DateTime.now(),
    ));

    await into(users).insert(UsersCompanion.insert(
      id: 'usr-ing-001',
      email: 'juan@sao.com',
      fullName: 'Juan Ingeniero',
      role: 'ENGINEER',
      status: 'ACTIVE',
      createdAt: DateTime.now(),
    ));

    // Projects
    await into(projects).insert(ProjectsCompanion.insert(
      id: 'proj-tmq-001',
      code: 'TMQ',
      name: 'Tehuantepec - Mérida - Querétaro',
      status: 'ACTIVE',
      createdAt: DateTime.now(),
    ));

    // Activity Types (catálogo real)
    final actTypes = [
      ('act-type-cam', 'Caminamiento', 'CAM'),
      ('act-type-reu', 'Reunión', 'REU'),
      ('act-type-asp', 'Asamblea Protocolizada', 'ASP'),
      ('act-type-cin', 'Consulta Indígena', 'CIN'),
      ('act-type-soc', 'Socialización', 'SOC'),
      ('act-type-ain', 'Acompañamiento Institucional', 'AIN'),
    ];

    for (final (id, name, code) in actTypes) {
      await into(activityTypes).insert(ActivityTypesCompanion.insert(
        id: id,
        name: name,
        code: code,
        projectId: const Value('proj-tmq-001'),
      ));
    }


    // Fronts
    final fronts = ['Frente A', 'Frente B', 'Frente C', 'Frente D'];
    for (var i = 0; i < fronts.length; i++) {
      await into(this.fronts).insert(FrontsCompanion.insert(
        id: 'front-00${i + 1}',
        name: fronts[i],
        projectId: 'proj-tmq-001',
      ));
    }

    // Municipalities
    final munis = [
      ('Tehuantepec', 'Oaxaca'),
      ('Coatzacoalcos', 'Veracruz'),
      ('Mérida', 'Yucatán'),
      ('Querétaro', 'Querétaro'),
    ];
    for (var i = 0; i < munis.length; i++) {
      await into(municipalities).insert(MunicipalitiesCompanion.insert(
        id: 'muni-00${i + 1}',
        name: munis[i].$1,
        state: munis[i].$2,
      ));
    }

    // Rejection Reasons
    final reasons = [
      'Foto desenfocada o borrosa',
      'No se observa el elemento requerido',
      'Ubicación GPS incorrecta',
      'Fecha/hora no coincide',
      'Mediciones incompletas',
      'Falta información requerida',
    ];
    for (var i = 0; i < reasons.length; i++) {
      await into(rejectionReasons).insert(RejectionReasonsCompanion.insert(
        id: 'reason-00${i + 1}',
        reason: reasons[i],
        isActive: const Value(true),
      ));
    }

    // No se precargan actividades/evidencias en bootstrap.
  }
}
