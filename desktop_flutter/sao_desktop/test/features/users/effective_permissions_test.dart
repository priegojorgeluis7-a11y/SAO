import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/users/effective_permissions.dart';

void main() {
  group('computeEffectivePermissionScopes', () {
    test('applies precedence deny > allow > role and project inheritance', () {
      final result = computeEffectivePermissionScopes(
        roleScopes: const [
          UserRoleScopeInput(role: 'OPERATIVO', projectId: null),
          UserRoleScopeInput(role: 'SUPERVISOR', projectId: 'tmq'),
        ],
        permissionScopes: const [
          UserPermissionScopeInput(
            permissionCode: 'manage_users',
            projectId: null,
            effect: 'allow',
          ),
          UserPermissionScopeInput(
            permissionCode: 'approve_activity',
            projectId: null,
            effect: 'deny',
          ),
          UserPermissionScopeInput(
            permissionCode: 'export_reports',
            projectId: 'tmq',
            effect: 'deny',
          ),
          UserPermissionScopeInput(
            permissionCode: 'close_activity',
            projectId: 'tmq',
            effect: 'allow',
          ),
        ],
        rolePermissions: const {
          'OPERATIVO': ['view_reports', 'approve_activity'],
          'SUPERVISOR': ['export_reports', 'approve_activity'],
        },
      );

      expect(result['*'], ['manage_users', 'view_reports']);
      expect(
        result['TMQ'],
        ['close_activity', 'manage_users', 'view_reports'],
      );
    });
  });

  group('computeEffectivePermissionScopeBreakdown', () {
    test('returns granted source and denied permissions per scope', () {
      final result = computeEffectivePermissionScopeBreakdown(
        roleScopes: const [
          UserRoleScopeInput(role: 'OPERATIVO', projectId: null),
        ],
        permissionScopes: const [
          UserPermissionScopeInput(
            permissionCode: 'close_activity',
            projectId: null,
            effect: 'allow',
          ),
          UserPermissionScopeInput(
            permissionCode: 'approve_activity',
            projectId: null,
            effect: 'deny',
          ),
        ],
        rolePermissions: const {
          'OPERATIVO': ['approve_activity', 'view_reports'],
        },
      );

      final global = result['*'];
      expect(global, isNotNull);
      expect(
        global!.granted.map((item) => '${item.code}:${item.source.name}').toList(),
        ['close_activity:directAllow', 'view_reports:role'],
      );
      expect(
        global.denied.map((item) => '${item.code}:${item.source.name}').toList(),
        ['approve_activity:directDeny'],
      );
    });
  });
}
