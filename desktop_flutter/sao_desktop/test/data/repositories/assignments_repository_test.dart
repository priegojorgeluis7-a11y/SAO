import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/data/repositories/assignments_repository.dart';
import 'package:sao_desktop/data/repositories/backend_api_client.dart';

class _FakeBackendApiClient extends BackendApiClient {
  _FakeBackendApiClient({this.postResponse, this.getResponse});

  dynamic postResponse;
  dynamic getResponse;
  String? lastPath;
  Map<String, dynamic>? lastPayload;

  @override
  Future<dynamic> postJson(String path, Map<String, dynamic> payload) async {
    lastPath = path;
    lastPayload = payload;
    return postResponse;
  }

  @override
  Future<dynamic> getJson(String path) async {
    lastPath = path;
    return getResponse;
  }
}

void main() {
  test('AssignmentItem keeps project id from API payload', () {
    final item = AssignmentItem.fromJson({
      'id': 'act-1',
      'project_id': 'tmq',
      'title': 'Actividad',
      'assignee_user_id': 'user-1',
      'assignee_name': 'Usuario',
    });

    expect(item.projectId, 'TMQ');
  });

  test('transferAssignment posts new assignee and reason', () async {
    final client = _FakeBackendApiClient(
      postResponse: {
        'id': 'act-1',
        'project_id': 'TMQ',
        'title': 'Actividad',
        'assignee_user_id': 'user-2',
        'assignee_name': 'Destino',
      },
    );
    final repository = AssignmentsRepository(client);

    final result = await repository.transferAssignment(
      assignmentId: 'act-1',
      assigneeUserId: 'user-2',
      reason: 'Cobertura',
    );

    expect(client.lastPath, '/api/v1/assignments/act-1/transfer');
    expect(client.lastPayload, {
      'assignee_user_id': 'user-2',
      'reason': 'Cobertura',
    });
    expect(result.assigneeUserId, 'user-2');
    expect(result.projectId, 'TMQ');
  });

  test('getTransferCandidates includes managers and admins from project users', () async {
    final client = _FakeBackendApiClient(
      getResponse: [
        {
          'id': 'admin-1',
          'full_name': 'Admin Uno',
          'email': 'admin@sao.mx',
          'role_name': 'ADMIN',
          'is_active': true,
        },
        {
          'id': 'coord-1',
          'full_name': 'Coord Uno',
          'email': 'coord@sao.mx',
          'role_name': 'COORD',
          'is_active': true,
        },
      ],
    );
    final repository = AssignmentsRepository(client);

    final result = await repository.getTransferCandidates('TMQ');

    expect(client.lastPath, '/api/v1/users?project_id=TMQ');
    expect(result.map((item) => item.userId), ['admin-1', 'coord-1']);
  });

  test('AssignmentFrontOption normalizes short PK values as chainage', () {
    final option = AssignmentFrontOption.fromJson({
      'id': 'front-1',
      'code': 'F1',
      'name': 'Frente 1',
      'pk_start': '90',
      'pk_end': '90+250',
    });

    expect(option.pkStart, 90000);
    expect(option.pkEnd, 90250);
  });
}
