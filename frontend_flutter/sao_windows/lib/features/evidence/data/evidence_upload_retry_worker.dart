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

  Future<void> processDueUploads({bool ignoreRetrySchedule = false}) async {
    if (_isTicking) return;
    _isTicking = true;

    try {
      final now = DateTime.now();
      final query = _db.select(_db.pendingUploads)
        ..where(
          (t) =>
              t.status.isNotValue('DONE') &
              (ignoreRetrySchedule
                  ? const drift.Constant(true)
                  : (t.nextRetryAt.isNull() |
                      t.nextRetryAt.isSmallerOrEqualValue(now))),
        )
        ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)])
        ..limit(10);
      final rows = await query.get();

      for (final row in rows) {
        await _processOne(row);
      }
    } finally {
      _isTicking = false;
    }
  }

  Future<void> _processOne(PendingUpload row) async {
    var currentRow = row;

    try {
      currentRow = await _resumeRetryableRow(row);

      if (currentRow.status == 'PENDING_INIT') {
        final init = await _repository.uploadInit(
          activityId: currentRow.activityId,
          mimeType: currentRow.mimeType,
          sizeBytes: currentRow.sizeBytes,
          fileName: currentRow.fileName,
        );

        await _updateRow(
          currentRow.id,
          PendingUploadsCompanion(
            evidenceId: drift.Value(init.evidenceId),
            objectPath: drift.Value(init.objectPath),
            signedUrl: drift.Value(init.signedUrl),
            status: const drift.Value('PENDING_UPLOAD'),
            lastError: const drift.Value(null),
          ),
        );

        return _processOne(
          currentRow.copyWith(
            status: 'PENDING_UPLOAD',
            evidenceId: drift.Value(init.evidenceId),
            objectPath: drift.Value(init.objectPath),
            signedUrl: drift.Value(init.signedUrl),
          ),
        );
      }

      if (currentRow.status == 'PENDING_UPLOAD') {
        if (currentRow.signedUrl == null || currentRow.signedUrl!.isEmpty) {
          throw StateError(
            'Missing signedUrl for pending upload ${currentRow.id}',
          );
        }

        final bytes = await File(currentRow.localPath).readAsBytes();
        await _repository.uploadBytesToSignedUrl(
          signedUrl: currentRow.signedUrl!,
          bytes: bytes,
          mimeType: currentRow.mimeType,
        );

        await _updateRow(
          currentRow.id,
          const PendingUploadsCompanion(
            status: drift.Value('PENDING_COMPLETE'),
            lastError: drift.Value(null),
          ),
        );

        return _processOne(
          currentRow.copyWith(
            status: 'PENDING_COMPLETE',
          ),
        );
      }

      if (currentRow.status == 'PENDING_COMPLETE') {
        final evidenceId = currentRow.evidenceId;
        if (evidenceId == null || evidenceId.isEmpty) {
          throw StateError(
            'Missing evidenceId for pending upload ${currentRow.id}',
          );
        }

        final description = await _resolveDescription(currentRow);
        await _repository.uploadComplete(
          evidenceId: evidenceId,
          description: description,
        );

        await _updateRow(
          currentRow.id,
          const PendingUploadsCompanion(
            status: drift.Value('DONE'),
            nextRetryAt: drift.Value(null),
            lastError: drift.Value(null),
          ),
        );
      }
    } catch (e) {
      final attempts = currentRow.attempts + 1;
      final delaySeconds = _backoffSeconds(attempts);
      final nextRetryAt = DateTime.now().add(Duration(seconds: delaySeconds));

      await _updateRow(
        currentRow.id,
        PendingUploadsCompanion(
          attempts: drift.Value(attempts),
          status: const drift.Value('ERROR'),
          nextRetryAt: drift.Value(nextRetryAt),
          lastError: drift.Value(e.toString()),
        ),
      );

      appLogger.w(
        '⚠️ Upload retry scheduled (${currentRow.id}) in ${delaySeconds}s: $e',
      );
    }
  }

  Future<PendingUpload> _resumeRetryableRow(PendingUpload row) async {
    if (row.status != 'ERROR') {
      return row;
    }

    final hasEvidenceId = row.evidenceId?.trim().isNotEmpty ?? false;
    final hasSignedUrl = row.signedUrl?.trim().isNotEmpty ?? false;
    final hasObjectPath = row.objectPath?.trim().isNotEmpty ?? false;

    final resumed = (hasEvidenceId && (hasSignedUrl || hasObjectPath))
        ? row.copyWith(status: 'PENDING_UPLOAD')
        : row.copyWith(
            status: 'PENDING_INIT',
            evidenceId: const drift.Value(null),
            objectPath: const drift.Value(null),
            signedUrl: const drift.Value(null),
          );

    await _updateRow(
      row.id,
      PendingUploadsCompanion(
        status: drift.Value(resumed.status),
        nextRetryAt: const drift.Value(null),
        lastError: const drift.Value(null),
        evidenceId: hasEvidenceId
            ? drift.Value(resumed.evidenceId)
            : const drift.Value(null),
        objectPath: hasObjectPath
            ? drift.Value(resumed.objectPath)
            : const drift.Value(null),
        signedUrl: hasSignedUrl
            ? drift.Value(resumed.signedUrl)
            : const drift.Value(null),
      ),
    );

    return resumed;
  }

  Future<String?> _resolveDescription(PendingUpload row) async {
    final queuedDescription = row.description?.trim();
    if (queuedDescription != null && queuedDescription.isNotEmpty) {
      return queuedDescription;
    }

    final evidenceQuery = _db.select(_db.evidences)
      ..where(
        (t) =>
            t.activityId.equals(row.activityId) &
            t.filePathLocal.equals(row.localPath),
      )
      ..limit(1);

    final evidenceRow = await evidenceQuery.getSingleOrNull();
    final caption = evidenceRow?.caption?.trim();
    return (caption != null && caption.isNotEmpty) ? caption : null;
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
