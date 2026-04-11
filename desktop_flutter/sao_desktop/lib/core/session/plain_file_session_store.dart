import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'session_store.dart';

class PlainFileSessionStore implements DesktopSessionStore {
  const PlainFileSessionStore();

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/sao_session.json');
  }

  @override
  Future<SessionData?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final data = SessionData.fromMap(map);
      return data.accessToken.trim().isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(SessionData data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data.toMap()));
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}