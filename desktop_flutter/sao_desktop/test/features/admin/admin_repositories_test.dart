import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/admin/data/admin_repositories.dart';

class FakeTransport implements AdminApiTransport {
  dynamic getResponse;
  dynamic postResponse;
  dynamic putResponse;
  String? lastPath;
  Object? lastBody;
  Map<String, String>? lastQuery;

  @override
  Future<dynamic> get(String path, {Map<String, String>? queryParams, String? token}) async {
    lastPath = path;
    lastQuery = queryParams;
    return getResponse;
  }

  @override
  Future<dynamic> patch(String path, {Object? body, String? token}) async {
    lastPath = path;
    lastBody = body;
    return postResponse;
  }

  @override
  Future<dynamic> post(String path, {Object? body, String? token}) async {
    lastPath = path;
    lastBody = body;
    return postResponse;
  }

  @override
  Future<dynamic> put(String path, {Object? body, String? token}) async {
    lastPath = path;
    lastBody = body;
    return putResponse;
  }
}

void main() {
  test('ProjectsRepository list parses projects', () async {
    final transport = FakeTransport()
      ..getResponse = [
        {
          'id': 'PRJ001',
          'name': 'Proyecto 1',
          'status': 'active',
          'start_date': '2026-01-01',
          'end_date': null,
        }
      ];

    final repository = ProjectsRepository(transport);
    final result = await repository.list('token');

    expect(result, hasLength(1));
    expect(result.first.id, 'PRJ001');
    expect(result.first.name, 'Proyecto 1');
    expect(transport.lastPath, '/api/v1/projects');
  });

  test('UsersRepository list sends role query', () async {
    final transport = FakeTransport()..getResponse = [];

    final repository = UsersRepository(transport);
    await repository.list('token', role: 'SUPERVISOR');

    expect(transport.lastPath, '/api/v1/users/admin');
    expect(transport.lastQuery, {'role': 'SUPERVISOR'});
  });

  test('AuditRepository parses audit rows', () async {
    final transport = FakeTransport()
      ..getResponse = [
        {
          'id': '1',
          'created_at': '2026-03-01T10:00:00Z',
          'actor_email': 'admin@example.com',
          'action': 'PROJECT_CREATED',
          'entity': 'project',
          'entity_id': 'PRJ001',
        }
      ];

    final repository = AuditRepository(transport);
    final result = await repository.list('token');

    expect(result, hasLength(1));
    expect(result.first.action, 'PROJECT_CREATED');
    expect(result.first.entityId, 'PRJ001');
  });
}
