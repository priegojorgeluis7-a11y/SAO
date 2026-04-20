import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sao_desktop/core/providers/project_providers.dart';
import 'package:sao_desktop/data/repositories/backend_api_client.dart';
import 'package:sao_desktop/features/auth/app_session_controller.dart';

class _FakeBackendApiClient extends BackendApiClient {
  const _FakeBackendApiClient(this.responses);

  final Map<String, dynamic> responses;
  static final List<String> calls = <String>[];

  @override
  Future<dynamic> getJson(String path) async {
    calls.add(path);
    if (!responses.containsKey(path)) {
      throw Exception('No fake response for $path');
    }
    final value = responses[path];
    if (value is Exception) {
      throw value;
    }
    return value;
  }
}

void main() {
  setUp(() {
    _FakeBackendApiClient.calls.clear();
  });

  test('parseAvailableProjectIds supports me/projects payload shape', () {
    final ids = parseAvailableProjectIds([
      {
        'project_id': 'tmq',
        'project_name': 'Transporte',
        'role_names': ['OPERATIVO'],
      },
      {
        'project_id': 'aer',
        'project_name': 'Aeropuertos',
        'role_names': ['SUPERVISOR'],
      },
    ]);

    expect(ids, <String>['TMQ', 'AER']);
  });

  test('availableProjectsProvider prefers scoped me/projects list', () async {
    const client = _FakeBackendApiClient({
      '/api/v1/me/projects': [
        {
          'project_id': 'tap',
          'project_name': 'Tapachula',
          'role_names': ['OPERATIVO'],
        },
      ],
    });

    final container = ProviderContainer(
      overrides: [
        backendApiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final ids = await container.read(availableProjectsProvider.future);

    expect(ids, <String>['TAP']);
    expect(_FakeBackendApiClient.calls.first, '/api/v1/me/projects');
  });

  test('availableProjectsProvider falls back to admin projects endpoint', () async {
    final client = _FakeBackendApiClient({
      '/api/v1/me/projects': Exception('403'),
      '/api/v1/projects': [
        {'id': 'GEN', 'name': 'General'},
        {'project_id': 'QIR', 'project_name': 'Queretaro'},
      ],
    });

    final container = ProviderContainer(
      overrides: [
        backendApiClientProvider.overrideWithValue(client),
        currentAppUserProvider.overrideWithValue(
          const AppUser(
            id: 'admin-1',
            email: 'admin@sao.mx',
            fullName: 'Admin',
            role: 'ADMIN',
            roles: ['ADMIN'],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ids = await container.read(availableProjectsProvider.future);

    expect(ids, <String>['GEN', 'QIR']);
    expect(_FakeBackendApiClient.calls, contains('/api/v1/projects'));
  });

  test('availableProjectsProvider keeps operative users scoped on fallback', () async {
    final client = _FakeBackendApiClient({
      '/api/v1/me/projects': Exception('403'),
      '/api/v1/projects': [
        {'id': 'GEN', 'name': 'General'},
        {'project_id': 'QIR', 'project_name': 'Queretaro'},
      ],
    });

    final container = ProviderContainer(
      overrides: [
        backendApiClientProvider.overrideWithValue(client),
        currentAppUserProvider.overrideWithValue(
          const AppUser(
            id: 'oper-1',
            email: 'operativo@sao.mx',
            fullName: 'Operativo TMQ',
            role: 'OPERATIVO',
            roles: ['OPERATIVO'],
            permissionScopes: [
              AppUserPermissionScope(
                permissionCode: 'activity.view',
                projectId: 'TMQ',
                effect: 'allow',
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ids = await container.read(availableProjectsProvider.future);

    expect(ids, <String>['TMQ']);
  });
}
