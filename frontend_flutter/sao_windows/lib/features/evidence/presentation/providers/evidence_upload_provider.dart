// lib/features/evidence/presentation/providers/evidence_upload_provider.dart
// Riverpod providers for evidence upload state management and orchestration.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/logger.dart';
import '../../data/evidence_upload_repository.dart';
import '../../services/camera_capture_service.dart';

/// Provider for evidence upload repository
final evidenceUploadRepositoryProvider =
    Provider<EvidenceUploadRepository>((ref) {
  return EvidenceUploadRepository();
});

/// State for single evidence upload
class EvidenceUploadState {
  final CapturedEvidence? evidence;
  final bool isLoading;
  final String? error;
  final String? evidenceId;
  final double? uploadProgress; // 0.0 to 1.0
  final bool isQueuedForOffline;

  const EvidenceUploadState({
    this.evidence,
    this.isLoading = false,
    this.error,
    this.evidenceId,
    this.uploadProgress,
    this.isQueuedForOffline = false,
  });

  EvidenceUploadState copyWith({
    CapturedEvidence? evidence,
    bool? isLoading,
    String? error,
    String? evidenceId,
    double? uploadProgress,
    bool? isQueuedForOffline,
  }) {
    return EvidenceUploadState(
      evidence: evidence ?? this.evidence,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      evidenceId: evidenceId ?? this.evidenceId,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isQueuedForOffline: isQueuedForOffline ?? this.isQueuedForOffline,
    );
  }

  bool get isSuccess => evidenceId != null && !isLoading;
  bool get isError => error != null && !isLoading;
}

/// StateNotifier for managing evidence upload
class EvidenceUploadNotifier extends StateNotifier<EvidenceUploadState> {
  final EvidenceUploadRepository _uploadRepository;

  EvidenceUploadNotifier(this._uploadRepository)
      : super(const EvidenceUploadState());

  /// Upload evidence with 3-step flow: init → PUT → complete
  Future<bool> uploadEvidence({
    required String activityId,
    required CapturedEvidence evidence,
  }) async {
    state = state.copyWith(isLoading: true, error: null, uploadProgress: 0.0);

    try {
      appLogger.i('📤 Starting evidence upload: ${evidence.fileName}');

      // Step 1: Initialize upload and get signed URL
      appLogger.d('📨 Initializing upload...');
      state = state.copyWith(uploadProgress: 0.1);
      final initResult = await _uploadRepository.uploadInit(
        activityId: activityId,
        mimeType: evidence.mimeType,
        sizeBytes: evidence.sizeBytes,
        fileName: evidence.fileName,
      );
      appLogger.d('✅ Upload initialized: ${initResult.evidenceId}');
      state = state.copyWith(uploadProgress: 0.3);

      // Step 2: Read file bytes and PUT to signed URL
      appLogger.d('📤 Uploading file to GCS (${evidence.fileSizeDisplay})...');
      final file = File(evidence.localPath);
      final bytes = await file.readAsBytes();

      await _uploadRepository.uploadBytesToSignedUrl(
        signedUrl: initResult.signedUrl,
        bytes: bytes,
        mimeType: evidence.mimeType,
      );
      appLogger.d('✅ File uploaded to GCS');
      state = state.copyWith(uploadProgress: 0.8);

      // Step 3: Finalize upload
      appLogger.d('🏁 Finalizing upload...');
      await _uploadRepository.uploadComplete(
        evidenceId: initResult.evidenceId,
        description: evidence.description,
      );
      appLogger.i(
        '✅ Evidence upload complete: ${initResult.evidenceId}',
      );

      state = state.copyWith(
        isLoading: false,
        uploadProgress: 1.0,
        evidenceId: initResult.evidenceId,
        evidence: evidence,
      );

      return true;
    } on DioException catch (e) {
      appLogger.w('⚠️ Network error during upload: ${e.message}');
      await _queueForOfflineRetry(activityId, evidence);
      return false;
    } catch (e) {
      final errorMsg = 'Failed to upload evidence: $e';
      appLogger.e('❌ Upload error', error: e);
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
      return false;
    }
  }

  /// Queue evidence for offline retry
  Future<void> _queueForOfflineRetry(
    String activityId,
    CapturedEvidence evidence,
  ) async {
    try {
      appLogger.i('📥 Queuing evidence for offline retry...');

      final queueId = await _uploadRepository.enqueuePendingUpload(
        activityId: activityId,
        localPath: evidence.localPath,
        fileName: evidence.fileName,
        mimeType: evidence.mimeType,
        sizeBytes: evidence.sizeBytes,
      );

      state = state.copyWith(
        isLoading: false,
        isQueuedForOffline: true,
        error: 'No connection - queued for upload (ID: $queueId)',
        evidence: evidence,
      );

      appLogger.i('✅ Queued for retry: $queueId');
    } catch (queueError) {
      appLogger.e('❌ Failed to queue for offline', error: queueError);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to queue: $queueError',
      );
    }
  }

  /// Reset upload state
  void reset() {
    state = const EvidenceUploadState();
  }
}

/// Provider for evidence upload state management
final evidenceUploadProvider =
    StateNotifierProvider<EvidenceUploadNotifier, EvidenceUploadState>((ref) {
  final repository = ref.watch(evidenceUploadRepositoryProvider);
  return EvidenceUploadNotifier(repository);
});

/// Helper provider to execute upload
final uploadEvidenceProvider = FutureProvider.family<bool, ({
  String activityId,
  CapturedEvidence evidence,
})>((ref, params) async {
  final notifier = ref.read(evidenceUploadProvider.notifier);
  return await notifier.uploadEvidence(
    activityId: params.activityId,
    evidence: params.evidence,
  );
});
