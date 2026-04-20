import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/users/users_page.dart';

void main() {
  group('resolveUserActivityOwnership', () {
    test('matches assigned user by name or email when ids differ', () {
      final ownership = resolveUserActivityOwnership(
        {
          'assigned_to_name': 'Jesus Gaspar Rios',
          'assigned_to_user_email': 'jesus@sao.mx',
        },
        userId: 'current-user-id',
        userEmail: 'jesus@sao.mx',
        fullName: 'jesus gaspar rios',
      );

      expect(ownership.assigned, isTrue);
      expect(ownership.isRelated, isTrue);
    });

    test('matches created user by creator aliases when ids differ', () {
      final ownership = resolveUserActivityOwnership(
        {
          'created_by_name': 'Jesus Gaspar Rios',
          'created_by_email': 'jesus@sao.mx',
        },
        userId: 'current-user-id',
        userEmail: 'jesus@sao.mx',
        fullName: 'jesus gaspar rios',
      );

      expect(ownership.created, isTrue);
      expect(ownership.isRelated, isTrue);
    });

    test('does not misassign by generic usuario field when assignee is different', () {
      final ownership = resolveUserActivityOwnership(
        {
          'assigned_to_name': 'María López',
          'assigned_to_user_email': 'maria@sao.mx',
          'usuario': 'Pedro Torres',
          'email': 'pedro@sao.mx',
        },
        userId: 'pedro-id',
        userEmail: 'pedro@sao.mx',
        fullName: 'Pedro Torres',
      );

      expect(ownership.assigned, isFalse);
      expect(ownership.isRelated, isFalse);
    });

    test('matches assigned user by name even with accents and spacing differences', () {
      final ownership = resolveUserActivityOwnership(
        {
          'assigned_to_name': 'José   Álvarez Ríos',
        },
        userId: 'current-user-id',
        userEmail: 'jose@sao.mx',
        fullName: 'Jose Alvarez Rios',
      );

      expect(ownership.assigned, isTrue);
      expect(ownership.isRelated, isTrue);
    });

    test('respects authoritative assignee for legacy activity rows', () {
      final ownership = resolveUserActivityOwnership(
        {
          'created_by_user_id': 'jesus-id',
          'created_by_name': 'Jesus Gaspar',
        },
        userId: 'jesus-id',
        userEmail: 'jesus@sao.mx',
        fullName: 'Jesus Gaspar',
        authoritativeAssigneeUserId: 'jorge-id',
        authoritativeAssigneeName: 'Jorge Priego Cruz',
      );

      expect(ownership.created, isFalse);
      expect(ownership.assigned, isFalse);
      expect(ownership.isRelated, isFalse);
    });

    test('does not treat creator as current owner when another assignee exists', () {
      final ownership = resolveUserActivityOwnership(
        {
          'created_by_user_id': 'pedro-id',
          'created_by_name': 'Pedro Torres',
          'assigned_to_user_id': 'maria-id',
          'assigned_to_name': 'María López',
          'assigned_to_user_email': 'maria@sao.mx',
        },
        userId: 'pedro-id',
        userEmail: 'pedro@sao.mx',
        fullName: 'Pedro Torres',
        includeCreated: false,
      );

      expect(ownership.created, isFalse);
      expect(ownership.assigned, isFalse);
      expect(ownership.isRelated, isFalse);
    });
  });
}
