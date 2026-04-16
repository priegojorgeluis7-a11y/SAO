import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

class ReportExportSettings {
  static const _defaultRootPathKey = 'reports_default_root_path';

  static Future<File> _settingsFile() async {
    final appDocs = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocs.path}/settings');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/report_export_settings.json');
  }

  static Future<Map<String, dynamic>> _readSettingsMap() async {
    final file = await _settingsFile();
    if (!await file.exists()) return <String, dynamic>{};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  static Future<void> _writeSettingsMap(Map<String, dynamic> data) async {
    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  static Future<String?> readDefaultRootPath() async {
    final map = await _readSettingsMap();
    final raw = map[_defaultRootPathKey]?.toString();
    final path = (raw ?? '').trim();
    return path.isEmpty ? null : path;
  }

  static Future<void> writeDefaultRootPath(String? path) async {
    final current = await _readSettingsMap();
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      current.remove(_defaultRootPathKey);
      await _writeSettingsMap(current);
      return;
    }
    current[_defaultRootPathKey] = normalized;
    await _writeSettingsMap(current);
  }

  static Future<String> defaultDocumentsRootPath() async {
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];

    if (home != null && home.trim().isNotEmpty) {
      final docsDir = Directory('$home/Documents');
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }
      return docsDir.path;
    }

    return Directory.current.path;
  }
}
