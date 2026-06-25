import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/admin/stats/admin_activity_stats_page.dart';

void main() {
  group('canViewAdminStats', () {
    test('allows access from auth roles and admin emails', () {
      expect(
        canViewAdminStats(authRoles: {'OPERATIVO', 'ADMIN'}, email: 'user@example.com'),
        isTrue,
      );
      expect(
        canViewAdminStats(authRoles: const {}, email: 'admin@sao.mx'),
        isTrue,
      );
      expect(
        canViewAdminStats(authRoles: const {}, email: 'admin.ops@example.com'),
        isTrue,
      );
    });

    test('allows access from local admin or supervisor roles', () {
      expect(
        canViewAdminStats(
          authRoles: const {},
          email: 'user@example.com',
          localRoleId: 1,
        ),
        isTrue,
      );
      expect(
        canViewAdminStats(
          authRoles: const {},
          email: 'user@example.com',
          localRoleName: 'SUPERVISOR',
        ),
        isTrue,
      );
    });

    test('blocks regular operative users', () {
      expect(
        canViewAdminStats(
          authRoles: const {'OPERATIVO'},
          email: 'user@example.com',
          localRoleId: 4,
          localRoleName: 'OPERATIVO',
        ),
        isFalse,
      );
    });
  });
}