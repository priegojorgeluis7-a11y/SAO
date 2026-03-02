import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:get_it/get_it.dart';

import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';
import 'evidence_upload_repository.dart';

class EvidenceUploadRetryWorker {
  final AppDb _db;
  final EvidenceUploadRepository _repository;
  final Duration _interval;

  Timer? _timer;
  bool _isRunning = false;
  bool _isTicking = false;

  EvidenceUploadRetryWorker({
    AppDb? db,
    EvidenceUploadRepository? repository,
    Duration? interval,
  })  : _db = db ?? GetIt.instance<AppDb>(),
        _repository = repository ?? GetIt.instance<EvidenceUploadRepository>(),
        _interval = interval ?? const Duration(seconds: 20);

  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _timer = Timer.periodic(_interval, (_) => processDueUploads());
    unawaited(processDueUploads());
    appLogger.i('🔁 EvidenceUploadRetryWorker started');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    appLogger.i('🛑 EvidenceUploadRetryWorker stopped');
  }

  Future<void> processDueUploads() async {
    if (_isTicking) return;
    _isTicking = true;

    try {
      final now = DateTime.now();
      final rows = await (_db.select(_db.pendingUploads)
            ..where((t) =>
                t.status.isNotValue('DONE') &
                (t.nextRetryAt.isNull() | t.nextRetryAt.isSmallerOrEqualValue(now)))
            ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)])
            ..limit(10))
          .get();

      for (final row in rows) {
        await _processOne(row);
      }
    } finally {
      _isTicking = false;
    }
  }

  Future<void> _processOne(PendingUpload row) async {
    try {
      if (row.status == 'PENDING_INIT') {
        final init = await _repository.uploadInit(
          activityId: row.activityId,
          mimeType: row.mimeType,
          sizeBytes: row.sizeBytes,
          fileName: row.fileName,
        );

        await _updateRow(
          row.id,
          PendingUploadsCompanion(
            evidenceId: drift.Value(init.evidenceId),
            objectPath: drift.Value(init.objectPath),
            signedUrl: drift.Value(init.signedUrl),
            status: const drift.Value('PENDING_UPLOAD'),
            lastError: const drift.Value(null),
          ),
        );

        return _processOne(
          row.copyWith(
            status: 'PENDING_UPLOAD',
            evidenceId: drift.Value(init.evidenceId),
            objectPath: drift.Value(init.objectPath),
            signedUrl: drift.Value(init.signedUrl),
          ),
        );
      }

      if (row.status == 'PENDING_UPLOAD') {
        if (row.signedUrl == null || row.signedUrl!.isEmpty) {
          throw StateError('Missing signedUrl for pending upload ${row.id}');
        }

        final bytes = await File(row.localPath).readAsBytes();
        await _repository.uploadBytesToSignedUrl(
          signedUrl: row.signedUrl!,
          bytes: bytes,
          mimeType: row.mimeType,
        );

        await _updateRow(
          row.id,
          const PendingUploadsCompanion(
            status: drift.Value('PENDING_COMPLETE'),
            lastError: drift.Value(null),
          ),
        );

        return _processOne(
          row.copyWith(
            status: 'PENDING_COMPLETE',
          ),
        );
      }

      if (row.status == 'PENDING_COMPLETE') {
        final evidenceId = row.evidenceId;
        if (evidenceId == null || evidenceId.isEmpty) {
          throw StateError('Missing evidenceId for pending upload ${row.id}');
        }

        await _repository.uploadComplete(evidenceId: evidenceId);

        await _updateRow(
          row.id,
          const PendingUploadsCompanion(
            status: drift.Value('DONE'),
            nextRetryAt: drift.Value(null),
            lastError: drift.Value(null),
          ),
        );
      }
    } catch (e) {
      final attempts = row.attempts + 1;
      final delaySeconds = _backoffSeconds(attempts);
      final nextRetryAt = DateTime.now().add(Duration(seconds: delaySeconds));

      await _updateRow(
        row.id,
        PendingUploadsCompanion(
          attempts: drift.Value(attempts),
          status: const drift.Value('ERROR'),
          nextRetryAt: drift.Value(nextRetryAt),
          lastError: drift.Value(e.toString()),
        ),
      );

      appLogger.w(
        '⚠️ Upload retry scheduled (${row.id}) in ${delaySeconds}s: $e',
      );
    }
  }

  int _backoffSeconds(int attempts) {
    final safeAttempt = attempts.clamp(1, 8);
    return 1 << safeAttempt;
  }

  Future<void> _updateRow(String id, PendingUploadsCompanion companion) async {
    await (_db.update(_db.pendingUploads)..where((t) => t.id.equals(id))).write(
      companion.copyWith(updatedAt: drift.Value(DateTime.now())),
    );
  }
}
