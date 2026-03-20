// lib/features/agenda/data/territory_api_repository.dart

import '../../../core/network/api_client.dart';

class FrontDto {
  final String id;
  final String projectId;
  final String code;
  final String name;
  final int? pkStart;
  final int? pkEnd;

  const FrontDto({
    required this.id,
    required this.projectId,
    required this.code,
    required this.name,
    this.pkStart,
    this.pkEnd,
  });

  factory FrontDto.fromJson(Map<String, dynamic> json) => FrontDto(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        pkStart: (json['pk_start'] as num?)?.toInt(),
        pkEnd: (json['pk_end'] as num?)?.toInt(),
      );
}

class TerritoryApiRepository {
  final ApiClient _apiClient;

  TerritoryApiRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// GET /territory/fronts?project_id={projectId}
  Future<List<FrontDto>> listFronts(String projectId) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/territory/fronts',
      queryParameters: {'project_id': projectId.trim().toUpperCase()},
    );
    final list = response.data ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(FrontDto.fromJson)
        .toList();
  }
}
