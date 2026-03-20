import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/shared_enums.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/activity_repository.dart';

final operationsDataProvider = FutureProvider<OperationsData>((ref) async {
  final activityRepo = ref.watch(activityRepositoryProvider);
  final catalogRepo = CatalogRepository();

  await catalogRepo.init();
  final pending = await activityRepo.watchPendingReview().first;

  return OperationsData(
    operationItems: pending.map(_toOperationItem).toList(growable: false),
    catalogRepo: catalogRepo,
  );
});

OperationItem _toOperationItem(ActivityWithDetails details) {
  final activity = details.activity;
  final createdAt = activity.createdAt;
  final age = DateTime.now().difference(createdAt);
  final isNew = age.inHours < 24;

  final risk = details.flags.gpsMismatch
      ? RiskLevel.prioritario.code
      : details.flags.checklistIncomplete
          ? RiskLevel.alto.code
          : details.flags.catalogChanged
              ? RiskLevel.medio.code
              : RiskLevel.bajo.code;

  final gpsDeltaMeters = details.flags.gpsMismatch ? 450.0 : 0.0;
  final syncedAgo = age.inMinutes < 60
      ? '${age.inMinutes} min'
      : '${age.inHours} h';

  return OperationItem(
    id: activity.id,
    type: details.activityType?.name ?? activity.title,
    pk: (activity.description ?? '-').trim().isEmpty ? '-' : activity.description!.trim(),
    engineer: details.assignedUser?.fullName ?? activity.assignedTo,
    municipality: details.municipality?.name ?? 'Sin municipio',
    state: details.municipality?.state ?? 'Sin estado',
    isNew: isNew,
    risk: risk,
    syncedAgo: syncedAgo,
    gpsDeltaMeters: gpsDeltaMeters,
    description: (activity.description ?? activity.title).trim(),
    classification: details.activityType?.code ?? 'GENERAL',
  );
}

class OperationsData {
  final List<OperationItem> operationItems;
  final CatalogRepository catalogRepo;
  
  OperationsData({
    required this.operationItems,
    required this.catalogRepo,
  });
}

class OperationItem {
  final String id;
  final String type;
  final String pk;
  final String engineer;
  final String municipality;
  final String state;
  final bool isNew;
  final String risk;
  final String syncedAgo;
  final double gpsDeltaMeters;
  final String description;
  final String classification;

  OperationItem({
    required this.id,
    required this.type,
    required this.pk,
    required this.engineer,
    required this.municipality,
    required this.state,
    required this.isNew,
    required this.risk,
    required this.syncedAgo,
    required this.gpsDeltaMeters,
    required this.description,
    required this.classification,
  });
}