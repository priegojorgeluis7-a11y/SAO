import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'backend_api_client.dart';

class OcrDetectedData {
  final String? date;
  final List<String> attendees;
  final List<String> agreements;
  final List<String> nextSteps;
  final List<String> keyPoints;

  const OcrDetectedData({
    required this.date,
    required this.attendees,
    required this.agreements,
    required this.nextSteps,
    required this.keyPoints,
  });

  factory OcrDetectedData.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    final dateRaw = json['date']?.toString().trim();
    return OcrDetectedData(
      date: (dateRaw == null || dateRaw.isEmpty) ? null : dateRaw,
      attendees: parseList(json['attendees']),
      agreements: parseList(json['agreements']),
      nextSteps: parseList(json['next_steps']),
      keyPoints: parseList(json['key_points']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'attendees': attendees,
      'agreements': agreements,
      'next_steps': nextSteps,
      'key_points': keyPoints,
    };
  }
}

class OcrExtractResult {
  final String sourceFileName;
  final String sourceType;
  final String extractionMode;
  final String text;
  final int textLength;
  final OcrDetectedData detected;

  const OcrExtractResult({
    required this.sourceFileName,
    required this.sourceType,
    required this.extractionMode,
    required this.text,
    required this.textLength,
    required this.detected,
  });

  factory OcrExtractResult.fromJson(Map<String, dynamic> json) {
    return OcrExtractResult(
      sourceFileName: (json['source_file_name'] ?? '').toString(),
      sourceType: (json['source_type'] ?? '').toString(),
      extractionMode: (json['extraction_mode'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      textLength: (json['text_length'] as num?)?.toInt() ?? 0,
      detected: OcrDetectedData.fromJson((json['detected'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }
}

class OcrLinkPayload {
  final String projectId;
  final String? activityId;
  final String? assistantId;
  final String? assistantName;
  final String? sourceFileName;
  final String extractedText;
  final String reviewedText;
  final OcrDetectedData? detectedData;

  const OcrLinkPayload({
    required this.projectId,
    required this.activityId,
    required this.assistantId,
    required this.assistantName,
    required this.sourceFileName,
    required this.extractedText,
    required this.reviewedText,
    required this.detectedData,
  });

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'activity_id': activityId,
      'assistant_id': assistantId,
      'assistant_name': assistantName,
      'source_file_name': sourceFileName,
      'extracted_text': extractedText,
      'reviewed_text': reviewedText,
      'extracted_fields': detectedData?.toJson(),
    };
  }
}

class OcrRepository {
  OcrRepository();

  final BackendApiClient _apiClient = const BackendApiClient();

  String? _findWorkspaceRoot() {
    Directory current = Directory.current.absolute;
    for (var i = 0; i < 8; i++) {
      final candidateA = File(
        p.join(current.path, 'desktop_flutter', 'sao_desktop', 'scripts', 'local_ocr.py'),
      );
      if (candidateA.existsSync()) {
        return current.path;
      }

      final candidateB = File(p.join(current.path, 'scripts', 'local_ocr.py'));
      if (candidateB.existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }
    return null;
  }

  String _resolveScriptPath(String? workspaceRoot) {
    if (workspaceRoot != null) {
      final candidateA = p.join(
        workspaceRoot,
        'desktop_flutter',
        'sao_desktop',
        'scripts',
        'local_ocr.py',
      );
      if (File(candidateA).existsSync()) {
        return candidateA;
      }

      final candidateB = p.join(workspaceRoot, 'scripts', 'local_ocr.py');
      if (File(candidateB).existsSync()) {
        return candidateB;
      }
    }

    throw const FileSystemException(
      'No se encontro scripts/local_ocr.py. Verifica el workspace SAO.',
    );
  }

  String _resolvePythonExecutable(String? workspaceRoot) {
    final envPath = Platform.environment['SAO_OCR_PYTHON']?.trim();
    if (envPath != null && envPath.isNotEmpty && File(envPath).existsSync()) {
      return envPath;
    }

    // Search for .venv in workspaceRoot and parent folders so packaged
    // executables started from build/Release can still find D:/SAO/.venv.
    if (workspaceRoot != null) {
      Directory current = Directory(workspaceRoot).absolute;
      for (var i = 0; i < 10; i++) {
        final candidate = p.join(current.path, '.venv', 'Scripts', 'python.exe');
        if (File(candidate).existsSync()) {
          return candidate;
        }

        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }

    return 'python';
  }

  Future<OcrExtractResult> extractFromPath(String filePath, {int maxPages = 8}) async {
    final sourceFile = File(filePath);
    if (!sourceFile.existsSync()) {
      throw FileSystemException('No existe el archivo para OCR local', filePath);
    }

    final workspaceRoot = _findWorkspaceRoot();
    final scriptPath = _resolveScriptPath(workspaceRoot);
    final pythonExecutable = _resolvePythonExecutable(workspaceRoot);

    // Write result to temp file – avoids stdout pipe deadlock on large PDFs.
    final tempDir = await Directory.systemTemp.createTemp('sao_ocr_');
    final outputFile = File(p.join(tempDir.path, 'result.json'));

    try {
      // Use Process.start so we can continuously drain stdout/stderr pipes
      // (onnxruntime writes verbose warnings; if the pipe fills it deadlocks).
      // A 3-minute timeout kills runaway processes.
      final processHandle = await Process.start(
        pythonExecutable,
        [
          scriptPath,
          '--file',
          sourceFile.absolute.path,
          '--max-pages',
          maxPages.clamp(1, 25).toString(),
          '--output',
          outputFile.absolute.path,
        ],
        workingDirectory: workspaceRoot ?? Directory.current.path,
        runInShell: true,
      );

      // Drain pipes concurrently – prevents pipe-buffer fill → deadlock.
      final stderrAccum = StringBuffer();
      final drainStdout = processHandle.stdout.drain<Object?>();
      final drainStderr = processHandle.stderr
          .transform(const SystemEncoding().decoder)
          .listen(stderrAccum.write)
          .asFuture<void>();

      late int exitCode;
      try {
        exitCode = await processHandle.exitCode.timeout(
          const Duration(seconds: 180),
        );
      } on TimeoutException {
        processHandle.kill(ProcessSignal.sigkill);
        throw Exception('OCR timeout: el proceso tardo mas de 3 minutos y fue cancelado.');
      }

      await Future.wait([drainStdout, drainStderr]);

      if (exitCode != 0) {
        final detail = stderrAccum.toString().trim();
        throw Exception('OCR local fallo (exit $exitCode): $detail');
      }

      if (!outputFile.existsSync()) {
        throw const FileSystemException('OCR no genero archivo de salida');
      }

      final jsonText = await outputFile.readAsString(encoding: utf8);
      if (jsonText.trim().isEmpty) {
        throw const FormatException('OCR local no devolvio salida JSON');
      }

      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('OCR local devolvio formato invalido');
      }

      return OcrExtractResult.fromJson(decoded);
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        debugPrint('OCR: limpieza de temp dir fallo: $e');
      }
    }
  }

  Future<void> linkMinute(OcrLinkPayload payload) async {
    await _apiClient.postJson('/api/v1/ocr/link', payload.toJson());
  }
}

final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  return OcrRepository();
});
