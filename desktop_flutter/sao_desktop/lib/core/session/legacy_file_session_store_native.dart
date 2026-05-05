import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'session_store.dart';

/// Read-only adapter for the legacy plain-text session file (sao_session.json).
///
/// Used solely during one-time migration to [SecureSessionStore].
/// After migration the file is deleted; this class has no further role.
class LegacyFileSessionStore {
  /// Allows tests to inject a specific file path instead of resolving via
  /// [getApplicationDocumentsDirectory].
  final String? _filePathOverride;

  const LegacyFileSessionStore({String? filePathOverride})
      : _filePathOverride = filePathOverride;

  Future<File> _file() async {
    if (_filePathOverride != null) return File(_filePathOverride);
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sao_session.json');
  }

  /// Reads the legacy file, deletes it, and returns the parsed [SessionData].
  /// Returns null if the file does not exist, is empty, or cannot be parsed.
  Future<SessionData?> readAndDelete() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final data = SessionData.fromMap(map);
      await file.delete();
      return data.accessToken.isNotEmpty ? data : null;
    } catch (_) {
      // Corrupt or unreadable file — delete it and skip migration.
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }
  }

  /// Deletes the legacy file if it exists. Safe to call at any time.
  Future<void> deleteIfExists() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
