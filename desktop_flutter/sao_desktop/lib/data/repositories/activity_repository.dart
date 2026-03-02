import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/data_mode.dart';
import '../database/app_database.dart';
import '../models/activity_model.dart';
import '../catalog/activity_status.dart';
import 'backend_api_client.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ActivityRepository(db);
});

class ActivityRepository {
  final AppDatabase _db;
  final BackendApiClient _apiClient = const BackendApiClient();

  ActivityRepository(this._db);

  // Obtener actividades pendientes de revisión
  Stream<List<ActivityWithDetails>> watchPendingReview() {
    if (AppDataMode.useMocks) {
      return Stream.value(_buildMockActivities());
    }

    return _watchPendingReviewFromBackendOrDb();
  }

  Stream<List<ActivityWithDetails>> _watchPendingReviewFromBackendOrDb() {
    return Stream.fromFuture(_fetchPendingReviewFromBackend()).asyncExpand((backendData) {
      if (backendData != null && backendData.isNotEmpty) {
        return Stream.value(backendData);
      }
      return _watchPendingReviewFromDb();
    });
  }

  Stream<List<ActivityWithDetails>> _watchPendingReviewFromDb() {
    return (_db.select(_db.activities)
          ..where((a) => a.status.equals(ActivityStatus.pendingReview))
          ..orderBy([(a) => OrderingTerm.desc(a.executedAt)]))
        .watch()
        .asyncMap((activities) async {
      final results = <ActivityWithDetails>[];
      for (final activity in activities) {
        final details = await _getActivityDetails(activity);
        results.add(details);
      }
      return results;
    });
  }

  Future<List<ActivityWithDetails>?> _fetchPendingReviewFromBackend() async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    if (baseUrl.isEmpty) return null;

    try {
      final decoded = await _apiClient.getJson('/api/v1/activities/pending-review');
      if (decoded is! List) return null;

      final now = DateTime.now();
      final result = <ActivityWithDetails>[];

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final activityId = (item['id'] ?? '').toString();
        if (activityId.isEmpty) continue;

        final activityTypeName = (item['activityTypeName'] ?? 'Actividad').toString();
        final activityTypeCode = (item['activityTypeCode'] ?? 'ACT').toString().toUpperCase();
        final status = (item['status'] ?? ActivityStatus.pendingReview).toString();

        final activity = Activity(
          id: activityId,
          projectId: (item['projectId'] ?? 'proj-backend').toString(),
          activityTypeId: (item['activityTypeId'] ?? 'act-type-backend').toString(),
          assignedTo: (item['assignedTo'] ?? 'usr-backend').toString(),
          frontId: (item['frontId'] as String?),
          municipalityId: (item['municipalityId'] as String?),
          title: (item['title'] ?? activityTypeName).toString(),
          description: item['description']?.toString(),
          status: status,
          executedAt: DateTime.tryParse((item['executedAt'] ?? '').toString()),
          reviewedAt: DateTime.tryParse((item['reviewedAt'] ?? '').toString()),
          reviewedBy: item['reviewedBy']?.toString(),
          reviewComments: item['reviewComments']?.toString(),
          latitude: (item['latitude'] as num?)?.toDouble(),
          longitude: (item['longitude'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse((item['createdAt'] ?? '').toString()) ?? now,
        );

        final type = ActivityType(
          id: activity.activityTypeId,
          name: activityTypeName,
          code: activityTypeCode,
          projectId: activity.projectId,
        );

        final user = User(
          id: activity.assignedTo,
          email: (item['assignedEmail'] ?? 'backend@sao.local').toString(),
          fullName: (item['assignedName'] ?? 'Sin responsable').toString(),
          role: (item['assignedRole'] ?? 'ENGINEER').toString(),
          status: 'ACTIVE',
          createdAt: now,
        );

        final municipality = Municipality(
          id: (item['municipalityId'] ?? 'mun-backend').toString(),
          name: (item['municipality'] ?? 'Sin municipio').toString(),
          state: (item['state'] ?? 'N/A').toString(),
        );

        final evidences = <Evidence>[];
        final evidenceCount = (item['evidenceCount'] as num?)?.toInt() ?? 0;
        for (var index = 0; index < evidenceCount; index++) {
          evidences.add(Evidence(
            id: 'ev-$activityId-$index',
            activityId: activityId,
            filePath: 'backend://evidence/$activityId/$index',
            fileType: 'IMAGE',
            capturedAt: now,
          ));
        }

        result.add(ActivityWithDetails(
          activity: activity,
          activityType: type,
          assignedUser: user,
          municipality: municipality,
          evidences: evidences,
        ));
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  List<ActivityWithDetails> _buildMockActivities() {
    final now = DateTime.now();

    ActivityWithDetails item({
      required String id,
      required String projectId,
      required String projectFront,
      required String activityName,
      required String activityCode,
      required String subcategory,
      required String purpose,
      required String pk,
      required String state,
      required String municipality,
      required String riskKeyword,
      required String result,
      required String status,
      required String assignedName,
      int evidenceCount = 0,
      required DateTime createdAt,
    }) {
      final activityTypeId = 'act-type-$activityCode-${id.toLowerCase()}';
      final activity = Activity(
        id: id,
        projectId: projectId,
        activityTypeId: activityTypeId,
        assignedTo: 'usr-$id',
        frontId: 'front-$projectFront',
        municipalityId: 'mun-${municipality.toLowerCase().replaceAll(' ', '-')}',
        title: '$activityName – $subcategory',
        description: '$purpose. $pk. Riesgo $riskKeyword.',
        status: status,
        reviewComments: result,
        executedAt: createdAt,
        createdAt: createdAt,
      );

      final evidences = List.generate(
        evidenceCount,
        (index) => Evidence(
          id: 'ev-$id-$index',
          activityId: id,
          filePath: 'mock://evidence/$id/$index.jpg',
          fileType: 'IMAGE',
          capturedAt: createdAt.add(Duration(minutes: index)),
        ),
      );

      return ActivityWithDetails(
        activity: activity,
        activityType: ActivityType(
          id: activityTypeId,
          name: activityName,
          code: activityCode,
          projectId: projectId,
        ),
        assignedUser: User(
          id: 'usr-$id',
          email: '${assignedName.toLowerCase().replaceAll(' ', '.')}@sao.local',
          fullName: assignedName,
          role: 'ENGINEER',
          status: 'ACTIVE',
          createdAt: now,
        ),
        front: Front(
          id: 'front-$projectFront',
          name: projectFront,
          projectId: projectId,
        ),
        municipality: Municipality(
          id: 'mun-${municipality.toLowerCase().replaceAll(' ', '-')}',
          name: municipality,
          state: state,
        ),
        evidences: evidences,
      );
    }

    return [
      item(
        id: 'ACT-MOCK-TMQ-PRIORITARIO',
        projectId: 'TMQ',
        projectFront: 'TMQ',
        activityName: 'Caminamiento',
        activityCode: 'CAM',
        subcategory: 'Verificación de DDV',
        purpose: 'Marcaje o actualización de DDV / trazo',
        pk: 'PK 10+200 – 10+800',
        state: 'Querétaro',
        municipality: 'Pedro Escobedo',
        riskKeyword: 'prioritario',
        result: 'Proceso en revisión / sin acuerdo final',
        status: ActivityStatus.pendingReview,
        assignedName: 'Juan Ingeniero',
        evidenceCount: 2,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      item(
        id: 'ACT-MOCK-TAP-MEDIO',
        projectId: 'TAP',
        projectFront: 'TAP',
        activityName: 'Reunión',
        activityCode: 'REU',
        subcategory: 'Técnica / Interinstitucional',
        purpose: 'Coordinación institucional',
        pk: 'PK 21+450',
        state: 'Hidalgo',
        municipality: 'Tizayuca',
        riskKeyword: 'medio',
        result: 'Actividad realizada conforme al programa',
        status: ActivityStatus.approved,
        assignedName: 'María Coordinadora',
        evidenceCount: 1,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      item(
        id: 'ACT-MOCK-TMQ-ALTO',
        projectId: 'TMQ',
        projectFront: 'TMQ',
        activityName: 'Asamblea Protocolizada',
        activityCode: 'ASP',
        subcategory: '1ª Asamblea Protocolizada (1AP)',
        purpose: 'Obtención de anuencia o firma de COP',
        pk: 'PK 34+100 – 34+600',
        state: 'Oaxaca',
        municipality: 'Tehuantepec',
        riskKeyword: 'alto',
        result: 'Sin quórum / segunda convocatoria programada',
        status: ActivityStatus.needsFix,
        assignedName: 'Carlos Supervisor',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      item(
        id: 'ACT-MOCK-TAP-BAJO',
        projectId: 'TAP',
        projectFront: 'TAP',
        activityName: 'Consulta Indígena',
        activityCode: 'CIN',
        subcategory: 'Etapa Informativa',
        purpose: 'Presentación general del proyecto',
        pk: 'PK 18+900',
        state: 'Estado de México',
        municipality: 'Temascalapa',
        riskKeyword: 'bajo',
        result: 'Se programa nueva reunión o seguimiento',
        status: ActivityStatus.pendingReview,
        assignedName: 'Ana Facilitadora',
        evidenceCount: 1,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  // Obtener detalles de una actividad
  Future<ActivityWithDetails> _getActivityDetails(Activity activity) async {
    final actType = await (_db.select(_db.activityTypes)
          ..where((t) => t.id.equals(activity.activityTypeId)))
        .getSingleOrNull();

    final user = await (_db.select(_db.users)
          ..where((u) => u.id.equals(activity.assignedTo)))
        .getSingleOrNull();

    Front? front;
    if (activity.frontId != null) {
      front = await (_db.select(_db.fronts)
            ..where((f) => f.id.equals(activity.frontId!)))
          .getSingleOrNull();
    }

    Municipality? muni;
    if (activity.municipalityId != null) {
      muni = await (_db.select(_db.municipalities)
            ..where((m) => m.id.equals(activity.municipalityId!)))
          .getSingleOrNull();
    }

    final evidences = await (_db.select(_db.evidences)
          ..where((e) => e.activityId.equals(activity.id))
          ..orderBy([(e) => OrderingTerm.asc(e.capturedAt)]))
        .get();

    return ActivityWithDetails(
      activity: activity,
      activityType: actType,
      assignedUser: user,
      front: front,
      municipality: muni,
      evidences: evidences,
    );
  }

  // Obtener actividad por ID con detalles
  Future<ActivityWithDetails?> getActivityById(String id) async {
    final activity = await (_db.select(_db.activities)
          ..where((a) => a.id.equals(id)))
        .getSingleOrNull();

    if (activity == null) return null;

    return _getActivityDetails(activity);
  }

  // Aprobar actividad
  Future<void> approveActivity(String activityId, String reviewerId) async {
    await (_db.update(_db.activities)..where((a) => a.id.equals(activityId)))
        .write(ActivitiesCompanion(
      status: const Value(ActivityStatus.approved),
      reviewedAt: Value(DateTime.now()),
      reviewedBy: Value(reviewerId),
    ));

    // Agregar a sync queue
    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
          id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPDATE',
          payloadJson: '{"status":"${ActivityStatus.approved}"}',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ));
  }

  // Rechazar actividad
  Future<void> rejectActivity(
    String activityId,
    String reviewerId,
    String comments,
  ) async {
    await (_db.update(_db.activities)..where((a) => a.id.equals(activityId)))
        .write(ActivitiesCompanion(
      status: const Value(ActivityStatus.rejected),
      reviewedAt: Value(DateTime.now()),
      reviewedBy: Value(reviewerId),
      reviewComments: Value(comments),
    ));

    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
          id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPDATE',
          payloadJson: '{"status":"${ActivityStatus.rejected}","comments":"$comments"}',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ));
  }

  // Marcar como necesita corrección
  Future<void> markNeedsFix(
    String activityId,
    String reviewerId,
    String comments,
  ) async {
    await (_db.update(_db.activities)..where((a) => a.id.equals(activityId)))
        .write(ActivitiesCompanion(
      status: const Value(ActivityStatus.needsFix),
      reviewedAt: Value(DateTime.now()),
      reviewedBy: Value(reviewerId),
      reviewComments: Value(comments),
    ));

    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
          id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPDATE',
          payloadJson: '{"status":"${ActivityStatus.needsFix}","comments":"$comments"}',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ));
  }

  // Obtener motivos de rechazo
  Future<List<RejectionReason>> getRejectionReasons() async {
    return (_db.select(_db.rejectionReasons)
          ..where((r) => r.isActive.equals(true)))
        .get();
  }
}
