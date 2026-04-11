// lib/data/repositories/projects_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';

class ProjectDto {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  final List<String>? scopes; // project scopes for RBAC

  const ProjectDto({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    this.scopes,
  });

  factory ProjectDto.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['code'] ?? '';
    final rawCode = json['code'] ?? '';
    final rawName = json['name'] ?? json['displayName'] ?? '';
    final rawIsActive = json['isActive'] ?? json['is_active'] ?? true;

    return ProjectDto(
      id: rawId.toString(),
      code: rawCode.toString().toUpperCase(),
      name: rawName.toString(),
      isActive: rawIsActive is bool ? rawIsActive : rawIsActive.toString().toLowerCase() == 'true',
      scopes: json['scopes'] != null ? List<String>.from(json['scopes'] as List) : null,
    );
  }
}

class ProjectsRepository {
  final ApiClient _apiClient;

  ProjectsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get user's projects (scoped by RBAC)
  Future<List<ProjectDto>> getMyProjects() async {
    try {
      appLogger.i('Fetching /me/projects...');
      final response = await _apiClient.get('/me/projects');
      final data = response.data;

      if (data is List) {
        return data
            .map((item) => ProjectDto.fromJson(item as Map<String, dynamic>))
            .where((p) => p.code.trim().isNotEmpty)
            .toList();
      } else if (data is Map && data.containsKey('projects')) {
        final projects = data['projects'];
        if (projects is List) {
          return projects
              .map((item) => ProjectDto.fromJson(item as Map<String, dynamic>))
              .where((p) => p.code.trim().isNotEmpty)
              .toList();
        }
      }

      appLogger.w('Unexpected response format from /me/projects: $data');
      return [];
    } catch (e) {
      appLogger.e('Error fetching /me/projects: $e');
      return [];
    }
  }

  /// Get all projects (legacy fallback)
  Future<List<ProjectDto>> getAllProjects() async {
    try {
      appLogger.i('Fetching /projects (fallback)...');
      final response = await _apiClient.get('/projects');
      final data = response.data;

      if (data is List) {
        return data
            .map((item) => ProjectDto.fromJson(item as Map<String, dynamic>))
            .where((p) => p.code.trim().isNotEmpty)
            .toList();
      } else if (data is Map && data.containsKey('projects')) {
        final projects = data['projects'];
        if (projects is List) {
          return projects
              .map((item) => ProjectDto.fromJson(item as Map<String, dynamic>))
              .where((p) => p.code.trim().isNotEmpty)
              .toList();
        }
      }

      appLogger.w('Unexpected response format from /projects: $data');
      return [];
    } catch (e) {
      appLogger.e('Error fetching /projects: $e');
      return [];
    }
  }

  /// Get projects with fallback chain
  Future<List<ProjectDto>> getProjects() async {
    // Try /me/projects first (scoped)
    final myProjects = await getMyProjects();
    if (myProjects.isNotEmpty) {
      return myProjects;
    }

    // Fallback to /projects
    return await getAllProjects();
  }
}

// ============ Riverpod Providers ============

final projectsRepositoryProvider = Provider((ref) {
  return ProjectsRepository(apiClient: GetIt.instance<ApiClient>());
});

/// All available projects
final allProjectsProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(projectsRepositoryProvider);
  return await repository.getProjects();
});

/// Active/selected project code
final activeProjectCodeProvider = StateProvider<String?>((ref) {
  return null; // Will be set via setActiveProject()
});

/// Convenience: get active project details from list
final activeProjectProvider = FutureProvider.autoDispose((ref) async {
  final activeCode = ref.watch(activeProjectCodeProvider);
  final allProjects = await ref.watch(allProjectsProvider.future);

  if (activeCode == null || activeCode.isEmpty) {
    return null;
  }

  try {
    return allProjects.firstWhere(
      (p) => p.code.toUpperCase() == activeCode.toUpperCase(),
    );
  } catch (_) {
    return null;
  }
});

/// Controller for project selection
final projectSelectionControllerProvider = Provider((ref) {
  return ProjectSelectionController(ref);
});

class ProjectSelectionController {
  final Ref _ref;

  ProjectSelectionController(this._ref);

  void setActiveProject(String projectCode) {
    _ref.read(activeProjectCodeProvider.notifier).state = projectCode.toUpperCase();
  }

  String? getActiveProject() {
    return _ref.read(activeProjectCodeProvider);
  }

  Future<void> refreshProjects() async {
    // Force-refresh the projects list
    final repository = _ref.read(projectsRepositoryProvider);
    await repository.getProjects();
    // Trigger refresh
    _ref.refresh(allProjectsProvider);
  }
}
