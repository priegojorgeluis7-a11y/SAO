import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/shared_enums.dart';
import '../../../data/repositories/catalog_repository.dart';

// Provider simplificado para demostración que usa catálogos reales
final operationsDataProvider = FutureProvider<OperationsData>((ref) async {
  final catalogRepo = CatalogRepository();
  
  // Inicializar catálogos
  await catalogRepo.init();
  
  // Generar datos de demostración usando el catálogo real
  final demoItems = _generateDemoItems(catalogRepo);
  
  return OperationsData(
    operationItems: demoItems,
    catalogRepo: catalogRepo,
  );
});

List<OperationItem> _generateDemoItems(CatalogRepository catalogRepo) {
  final activities = catalogRepo.getActivityTypes();
  final states = catalogRepo.getStates();
  final municipalities = catalogRepo.getMunicipalities();
  
  return List.generate(15, (i) {
    final activity = activities[i % activities.length];
    final riskLevels = [RiskLevel.bajo, RiskLevel.medio, RiskLevel.alto, RiskLevel.prioritario];
    final risk = riskLevels[i % 4];
    
    return OperationItem(
      id: 'ACT-${1000 + i}',
      type: activity.name,  // 📱 Del catálogo real
      pk: '142+${(i * 10).toString().padLeft(3, '0')}',
      engineer: 'Ing. Ramírez',
      municipality: municipalities[i % municipalities.length],  // 📱 Del catálogo real 
      state: states[i % states.length],  // 📱 Del catálogo real
      isNew: i < 4,
      risk: risk.code,  // 📱 Homologado con app móvil
      syncedAgo: '${(i + 2)} min',
      gpsDeltaMeters: (i % 5 == 0) ? 450 : (i % 7 == 0) ? 35 : 3,
      description: 'Actividad de ${activity.name.toLowerCase()} en zona ${i + 1}',
      classification: ['Ambiental', 'Social', 'Jurídico', 'Técnico'][i % 4],
    );
  });
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