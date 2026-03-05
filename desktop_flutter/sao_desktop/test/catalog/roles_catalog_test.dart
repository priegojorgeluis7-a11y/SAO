import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sao_desktop/catalog/roles_catalog.dart';
import 'package:sao_desktop/ui/theme/sao_colors.dart';

void main() {
  group('RolesCatalog helpers', () {
    test('finders return known roles and null for unknown', () {
      expect(RolesCatalog.findById('admin')?.label, 'Administrador');
      expect(RolesCatalog.findById('missing'), isNull);
      expect(RolesCatalog.findByLabel('coordinador')?.id, 'coordinador');
      expect(RolesCatalog.findByLabel('NA'), isNull);
    });

    test('collections and ordering are stable', () {
      expect(RolesCatalog.ids, contains('operativo'));
      expect(RolesCatalog.labels, contains('Operativo'));
      expect(RolesCatalog.orderedByLevel.first.id, 'consulta');
      expect(RolesCatalog.orderedByLevel.last.id, 'admin');
      expect(RolesCatalog.approvalRoles.map((r) => r.id), contains('coordinador'));
      expect(RolesCatalog.adminRoles.every((r) => r.level >= 2), isTrue);
    });

    test('permission checks and defaults work', () {
      expect(
        RolesCatalog.hasPermission('admin', RolesCatalog.permManageUsers),
        isTrue,
      );
      expect(
        RolesCatalog.hasPermission('consulta', RolesCatalog.permManageUsers),
        isFalse,
      );
      expect(RolesCatalog.hasPermission('missing', RolesCatalog.permViewReports), isFalse);
      expect(RolesCatalog.getColor('missing'), SaoColors.gray500);
    });

    test('dropdownItems supports id and label modes', () {
      final idItems = RolesCatalog.dropdownItems();
      final labelItems = RolesCatalog.dropdownItems(useId: false);

      expect(idItems, hasLength(RolesCatalog.all.length));
      expect(labelItems, hasLength(RolesCatalog.all.length));
      expect(idItems.first.value, RolesCatalog.all.first.id);
      expect(labelItems.first.value, RolesCatalog.all.first.label);
    });

    testWidgets('badge renders known and fallback role labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RolesCatalog.badge('admin'),
                RolesCatalog.badge('missing'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ADMINISTRADOR'), findsOneWidget);
      // Unknown role falls back to `operativo`.
      expect(find.text('OPERATIVO'), findsOneWidget);
    });
  });
}
