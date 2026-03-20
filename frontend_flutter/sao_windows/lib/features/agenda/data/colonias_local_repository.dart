// lib/features/agenda/data/colonias_local_repository.dart
import 'package:drift/drift.dart';

import '../../../data/local/app_db.dart';

/// Repositorio local para el catálogo de colonias por municipio.
/// Usa SQL directo (customStatement / customSelect) para no depender de codegen de Drift.
class ColoniasLocalRepository {
  final AppDb _db;

  ColoniasLocalRepository(this._db);

  /// Devuelve las colonias registradas para un municipio, ordenadas por popularidad.
  Future<List<String>> getColonias(String municipio) async {
    final rows = await _db.customSelect(
      'SELECT colonia FROM local_colonias '
      'WHERE municipio = ? '
      'ORDER BY usage_count DESC, colonia ASC',
      variables: [Variable.withString(municipio.trim())],
    ).get();
    return rows.map((r) => r.read<String>('colonia')).toList();
  }

  /// Inserta la colonia si no existe y actualiza su contador de uso.
  Future<void> addOrIncrementColonia({
    required String municipio,
    required String colonia,
    String? estado,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.customInsert(
      'INSERT INTO local_colonias (municipio, estado, colonia, usage_count, created_at) '
      'VALUES (?, ?, ?, 1, ?) '
      'ON CONFLICT(municipio, colonia) DO UPDATE SET usage_count = usage_count + 1',
      variables: [
        Variable.withString(municipio.trim()),
        estado != null ? Variable.withString(estado.trim()) : const Variable(null),
        Variable.withString(colonia.trim()),
        Variable.withString(now),
      ],
    );
  }

  /// Elimina una colonia del catálogo local (por si el usuario quiere limpiarla).
  Future<void> deleteColonia({required String municipio, required String colonia}) async {
    await _db.customUpdate(
      'DELETE FROM local_colonias WHERE municipio = ? AND colonia = ?',
      variables: [
        Variable.withString(municipio.trim()),
        Variable.withString(colonia.trim()),
      ],
    );
  }
}
