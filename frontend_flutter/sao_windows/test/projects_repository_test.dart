import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/repositories/projects_repository.dart';

void main() {
  group('Problema 3: Dynamic Projects', () {
    test('should parse ProjectDto from JSON with complete fields', () {
      final json = {
        'id': 'proj-1',
        'code': 'tmq',
        'name': 'Transmilenio Query',
        'isActive': true,
        'scopes': ['READ', 'WRITE']
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.id, 'proj-1');
      expect(dto.code, 'TMQ'); // Should uppercase
      expect(dto.name, 'Transmilenio Query');
      expect(dto.isActive, true);
      expect(dto.scopes, ['READ', 'WRITE']);
    });

    test('should map displayName when name field is missing', () {
      final json = {
        'id': 'proj-2',
        'code': 'SAO',
        'displayName': 'SAO Admin Console',
        'is_active': true
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.name, 'SAO Admin Console');
    });

    test('should default isActive to true when not provided', () {
      final json = {
        'id': 'proj-3',
        'code': 'CUSTOM',
        'name': 'Custom Project'
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.isActive, true);
    });

    test('should handle null scopes gracefully', () {
      final json = {
        'id': 'proj-4',
        'code': 'NOSCOPES',
        'name': 'No Scopes Project',
        'isActive': false
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.scopes, null);
    });

    test('should parse scopes as nullable list when present', () {
      final json = {
        'id': 'proj-5',
        'code': 'SCOPED',
        'name': 'Scoped Project',
        'scopes': ['ADMIN', 'AUDIT']
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.scopes, ['ADMIN', 'AUDIT']);
    });

    test('should handle alternative field names (code vs id)', () {
      final json = {
        'code': 'ALT_CODE',
        'name': 'Alternative Naming'
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.code, 'ALT_CODE');
      expect(dto.id, 'ALT_CODE'); // Should use code if id is missing
    });

    test('should uppercase code field consistently', () {
      final json1 = {'code': 'lowercase', 'name': 'Project 1'};
      final json2 = {'code': 'UPPERCASE', 'name': 'Project 2'};
      final json3 = {'code': 'MixedCase', 'name': 'Project 3'};

      final dto1 = ProjectDto.fromJson(json1);
      final dto2 = ProjectDto.fromJson(json2);
      final dto3 = ProjectDto.fromJson(json3);

      expect(dto1.code, 'LOWERCASE');
      expect(dto2.code, 'UPPERCASE');
      expect(dto3.code, 'MIXEDCASE');
    });

    test('should handle is_active field (snake_case)', () {
      final json = {
        'code': 'SNAKE',
        'name': 'Snake Case Project',
        'is_active': false // snake_case version
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.isActive, false);
    });

    test('should prefer isActive over is_active', () {
      final json = {
        'code': 'PREF',
        'name': 'Preference Test',
        'isActive': true,
        'is_active': false // Should be ignored
      };

      final dto = ProjectDto.fromJson(json);

      expect(dto.isActive, true);
    });
  });
}

