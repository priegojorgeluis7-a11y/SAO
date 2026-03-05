// lib/catalog/catalog_index.dart
/// Índice central de catálogos globales del SAO
/// Importa este archivo para acceder a todos los catálogos:
///
/// ```dart
/// import 'package:sao_windows/catalog/catalog_index.dart';
///
/// // Uso:
/// final status = StatusCatalog.nuevo;
/// final risk = RiskCatalog.prioritario;
/// final role = RolesCatalog.coordinador;
/// final project = ProjectsCatalog.tmq;
/// // Actividades: usar CatalogRepository.activities (bundle)
/// ```
library;


export 'status_catalog.dart';
export 'risk_catalog.dart';
export 'roles_catalog.dart';
export 'projects_catalog.dart';
