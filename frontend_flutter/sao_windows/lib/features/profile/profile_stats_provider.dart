import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:drift/drift.dart';
import '../../data/local/app_db.dart';
import '../../features/auth/application/auth_providers.dart';

class ProfileStats {
  final int totalActivities;
  final int completedActivities;
  final int syncedActivities;
  final int draftActivities;
  final String? roleName;
  final bool loading;
  final bool loadingRole;
  final bool loadingStats;
  final String? error;

  ProfileStats({
    required this.totalActivities,
    required this.completedActivities,
    required this.syncedActivities,
    required this.draftActivities,
    required this.roleName,
    required this.loading,
    required this.loadingRole,
    required this.loadingStats,
    this.error,
  });

  ProfileStats copyWith({
    int? totalActivities,
    int? completedActivities,
    int? syncedActivities,
    int? draftActivities,
    String? roleName,
    bool? loading,
    bool? loadingRole,
    bool? loadingStats,
    String? error,
  }) {
    return ProfileStats(
      totalActivities: totalActivities ?? this.totalActivities,
      completedActivities: completedActivities ?? this.completedActivities,
      syncedActivities: syncedActivities ?? this.syncedActivities,
      draftActivities: draftActivities ?? this.draftActivities,
      roleName: roleName ?? this.roleName,
      loading: loading ?? this.loading,
      loadingRole: loadingRole ?? this.loadingRole,
      loadingStats: loadingStats ?? this.loadingStats,
      error: error ?? this.error,
    );
  }

  static ProfileStats initial() => ProfileStats(
        totalActivities: 0,
        completedActivities: 0,
        syncedActivities: 0,
        draftActivities: 0,
        roleName: null,
        loading: true,
        loadingRole: true,
        loadingStats: true,
        error: null,
      );
}

final profileStatsProvider = StateNotifierProvider<ProfileStatsNotifier, ProfileStats>((ref) {
  return ProfileStatsNotifier(ref);
});

class ProfileStatsNotifier extends StateNotifier<ProfileStats> {
  final Ref ref;
  ProfileStatsNotifier(this.ref) : super(ProfileStats.initial()) {
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([
      loadRole(),
      loadStats(),
    ]);
  }

  Future<void> loadRole() async {
    state = state.copyWith(loadingRole: true);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = state.copyWith(loadingRole: false);
      return;
    }
    final db = GetIt.I<AppDb>();
    try {
      final localUser = await (db.select(db.users)
            ..where((t) => t.id.equals(user.id)))
          .getSingleOrNull();
      final roleRow = localUser == null
          ? null
          : await (db.select(db.roles)
                ..where((r) => r.id.equals(localUser.roleId)))
              .getSingleOrNull();
      state = state.copyWith(roleName: roleRow?.name, loadingRole: false);
    } catch (e) {
      state = state.copyWith(loadingRole: false, error: e.toString());
    }
  }

  Future<void> loadStats() async {
    state = state.copyWith(loadingStats: true);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = state.copyWith(loadingStats: false);
      return;
    }
    final db = GetIt.I<AppDb>();
    try {
      final userId = user.id.trim();

      final createdRows = await (db.select(db.activities)
            ..where((t) => t.createdByUserId.equals(userId)))
          .get();

      final directlyAssignedRows = await (db.select(db.activities)
            ..where((t) => t.assignedToUserId.equals(userId)))
          .get();

      final assignedFieldRows = await (db.select(db.activityFields)
            ..where(
              (t) =>
                  t.fieldKey.equals('assignee_user_id') &
                  t.valueText.equals(userId),
            ))
          .get();

      final assignedActivityIds = <String>{
        ...directlyAssignedRows.map((r) => r.id),
        ...assignedFieldRows.map((r) => r.activityId),
      };

      final agendaRows = await (db.select(db.agendaAssignments)
            ..where((t) => t.resourceId.equals(userId)))
          .get();
      for (final row in agendaRows) {
        final activityId = row.activityId?.trim();
        if (activityId != null && activityId.isNotEmpty) {
          assignedActivityIds.add(activityId);
        }

        final assignmentId = row.id.trim();
        if (assignmentId.isNotEmpty) {
          assignedActivityIds.add(assignmentId);
        }
      }

      final assignedRows = assignedActivityIds.isEmpty
          ? <Activity>[...directlyAssignedRows]
          : await (db.select(db.activities)..where((t) => t.id.isIn(assignedActivityIds.toList())))
              .get();

      final mergedById = <String, Activity>{
        for (final row in createdRows) row.id: row,
        for (final row in directlyAssignedRows) row.id: row,
        for (final row in assignedRows) row.id: row,
      };
      final myRows = mergedById.values.where((a) => a.status != 'CANCELED').toList();

      final knownIds = mergedById.keys.toSet();
      final agendaOnlyKeys = <String>{};
      var agendaOnlySynced = 0;
      for (final row in agendaRows) {
        final activityId = row.activityId?.trim();
        final assignmentId = row.id.trim();
        final matchesKnown =
            (activityId != null && activityId.isNotEmpty && knownIds.contains(activityId)) ||
            (assignmentId.isNotEmpty && knownIds.contains(assignmentId));
        if (matchesKnown) {
          continue;
        }

        final logicalKey = (activityId != null && activityId.isNotEmpty)
            ? activityId
            : assignmentId;
        if (logicalKey.isEmpty || !agendaOnlyKeys.add(logicalKey)) {
          continue;
        }

        if (row.syncStatus.trim().toLowerCase() == 'synced') {
          agendaOnlySynced++;
        }
      }

      state = state.copyWith(
        totalActivities: myRows.length + agendaOnlyKeys.length,
        completedActivities: myRows.where((a) => a.finishedAt != null).length,
        syncedActivities: myRows.where((a) => a.status == 'SYNCED').length + agendaOnlySynced,
        draftActivities: myRows
            .where((a) => a.status == 'DRAFT' || a.status == 'REVISION_PENDIENTE')
            .length,
        loadingStats: false,
      );
    } catch (e) {
      state = state.copyWith(loadingStats: false, error: e.toString());
    }
  }
}
