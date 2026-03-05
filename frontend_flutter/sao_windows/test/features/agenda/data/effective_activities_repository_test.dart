import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/agenda/data/effective_activities_repository.dart';

class _FakeEffectiveActivitiesLocalStore implements EffectiveActivitiesLocalStore {
  _FakeEffectiveActivitiesLocalStore(this._rows);

  final List<EffectiveActivityRecord> _rows;

  @override
  Future<List<EffectiveActivityRecord>> getAllActivities() async => _rows;
}

void main() {
  group('EffectiveActivitiesRepository', () {
    test('retorna actividades enabled y ordenadas por sortOrder', () async {
      final repo = EffectiveActivitiesRepository(
        localStore: _FakeEffectiveActivitiesLocalStore(
          const [
            EffectiveActivityRecord(
              id: 'a3',
              name: 'C',
              isEnabled: true,
              sortOrder: 3,
              versionId: 'v1',
            ),
            EffectiveActivityRecord(
              id: 'a2',
              name: 'B',
              isEnabled: false,
              sortOrder: 1,
              versionId: 'v1',
            ),
            EffectiveActivityRecord(
              id: 'a1',
              name: 'A',
              isEnabled: true,
              sortOrder: 2,
              versionId: 'v1',
            ),
          ],
        ),
      );

      final result = await repo.listEnabledOrdered();

      expect(result.map((row) => row.id).toList(), ['a1', 'a3']);
      expect(result.every((row) => row.versionId == 'v1'), isTrue);
    });
  });
}
