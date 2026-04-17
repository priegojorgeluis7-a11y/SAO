import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/home/home_page.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

void main() {
  group('canTransferResponsibilityForViewer', () {
    test('allows privileged managers to transfer active assignments', () {
      final allowed = canTransferResponsibilityForViewer(
        isPrivilegedAssignmentManager: true,
        isOperativeViewer: false,
        isAssignedToCurrentUser: false,
        isOfflineMode: false,
        executionState: ExecutionState.pendiente,
      );

      expect(allowed, isTrue);
    });

    test('allows operative assignee to transfer their own assignment', () {
      final allowed = canTransferResponsibilityForViewer(
        isPrivilegedAssignmentManager: false,
        isOperativeViewer: true,
        isAssignedToCurrentUser: true,
        isOfflineMode: false,
        executionState: ExecutionState.enCurso,
      );

      expect(allowed, isTrue);
    });

    test('blocks transfer when offline or already completed', () {
      expect(
        canTransferResponsibilityForViewer(
          isPrivilegedAssignmentManager: true,
          isOperativeViewer: false,
          isAssignedToCurrentUser: false,
          isOfflineMode: true,
          executionState: ExecutionState.pendiente,
        ),
        isFalse,
      );

      expect(
        canTransferResponsibilityForViewer(
          isPrivilegedAssignmentManager: true,
          isOperativeViewer: false,
          isAssignedToCurrentUser: false,
          isOfflineMode: false,
          executionState: ExecutionState.terminada,
        ),
        isFalse,
      );
    });
  });
}
