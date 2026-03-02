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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedInitialData();
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

    final subcategoriesByCode = <String, List<String>>{
      'CAM': [
        'Verificación de DDV',
        'Marcaje de afectaciones',
        'Revisión de accesos / BDT',
        'Seguimiento técnico',
      ],
      'REU': [
        'Técnica / Interinstitucional',
        'Ejidal / Comisariado',
        'Municipal / Estatal / Protección Civil',
        'Seguimiento / Evaluación',
        'Informativa',
        'Mesa Técnica',
      ],
      'ASP': [
        '1ª Asamblea Protocolizada (1AP)',
        '1ª Asamblea Protocolizada Permanente',
        '2ª Asamblea Protocolizada (2AP)',
        '2ª Asamblea Protocolizada Permanente',
        'Asamblea Informativa',
      ],
      'CIN': [
        'Etapa Informativa',
        'Etapa de Construcción de Acuerdos',
        'Etapa de Actos y Acuerdos',
      ],
      'SOC': [
        'Presentación Comunitaria',
        'Difusión de Información',
        'Atención a Inquietudes',
      ],
      'AIN': [
        'Técnico',
        'Social',
        'Documental',
      ],
    };

    final purposeBySubcategory = <String, String>{
      'Verificación de DDV': 'Verificación de afectaciones',
      'Marcaje de afectaciones': 'Marcaje o actualización de DDV / trazo',
      'Revisión de accesos / BDT': 'Análisis de accesos y pasos alternos',
      'Técnica / Interinstitucional': 'Coordinación institucional',
      'Ejidal / Comisariado': 'Atención a inconformidades o conflictos',
      'Informativa': 'Presentación general del proyecto',
      '1ª Asamblea Protocolizada (1AP)': 'Entrega de documentación / Convocatorias',
      '2ª Asamblea Protocolizada (2AP)': 'Obtención de anuencia o firma de COP',
      'Etapa Informativa': 'Presentación general del proyecto',
      'Etapa de Construcción de Acuerdos': 'Atención a inconformidades o conflictos',
      'Presentación Comunitaria': 'Presentación general del proyecto',
      'Atención a Inquietudes': 'Atención a inconformidades o conflictos',
      'Documental': 'Seguimiento administrativo / documental',
    };

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

    // Activities (mocks basados en catálogo real)
    final now = DateTime.now();
    for (var i = 0; i < 10; i++) {
      final actId = 'act-${now.millisecondsSinceEpoch}-$i';
      final actType = actTypes[i % actTypes.length];
      final activityCode = actType.$3;
      final activityName = actType.$2;
      final subcategories = subcategoriesByCode[activityCode] ?? const <String>[];
      final subcategory = subcategories.isEmpty
          ? ''
          : subcategories[i % subcategories.length];
      final purpose = purposeBySubcategory[subcategory] ?? 'Seguimiento administrativo / documental';
      final title = subcategory.isEmpty
          ? '$activityCode $activityName'
          : '$activityCode $activityName – $subcategory';

      await into(activities).insert(ActivitiesCompanion.insert(
        id: actId,
        projectId: 'proj-tmq-001',
        activityTypeId: actType.$1,
        assignedTo: 'usr-ing-001',
        frontId: Value('front-00${(i % 4) + 1}'),
        municipalityId: Value('muni-00${(i % 4) + 1}'),
        title: title,
        description: Value(purpose),
        status: 'PENDING_REVIEW',
        executedAt: Value(now.subtract(Duration(days: i))),
        createdAt: now.subtract(Duration(days: i)),
        latitude: Value(19.4326 + (i * 0.1)),
        longitude: Value(-99.1332 + (i * 0.1)),
      ));

      // 2-4 evidencias por actividad
      final numEvidences = 2 + (i % 3);
      for (var j = 0; j < numEvidences; j++) {
        await into(evidences).insert(EvidencesCompanion.insert(
          id: 'evid-$actId-$j',
          activityId: actId,
          filePath: 'assets/sample_images/photo_${i}_$j.jpg',
          fileType: 'IMAGE',
          caption: Value('Evidencia fotográfica ${j + 1}'),
          capturedAt: now.subtract(Duration(days: i, hours: j)),
          latitude: Value(19.4326 + (i * 0.1)),
          longitude: Value(-99.1332 + (i * 0.1)),
        ));
      }
    }
  }
}
