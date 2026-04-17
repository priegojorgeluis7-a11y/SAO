// lib/features/evidence/presentation/evidence_capture_page.dart
// Main evidence capture page for camera/gallery selection and evidence submission.
// Flows: Select camera/gallery → Capture/Pick → Add description → Preview → Submit

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/utils/snackbar.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../core/utils/logger.dart';
import '../services/camera_capture_service.dart';
import '../data/evidence_upload_repository.dart';
import 'widgets/evidence_preview_card.dart';
import 'widgets/evidence_description_form.dart';
import 'widgets/gps_location_display.dart';

class EvidenceCaptureArguments {
  /// Activity ID to attach evidence to
  final String activityId;

  /// Optional field key (if specific field in form)
  final String? fieldKey;

  EvidenceCaptureArguments({
    required this.activityId,
    this.fieldKey,
  });
}

class EvidenceCapturePage extends StatefulWidget {
  final String activityId;
  final String? fieldKey;
  final VoidCallback? onEvidenceAdded;

  const EvidenceCapturePage({
    super.key,
    required this.activityId,
    this.fieldKey,
    this.onEvidenceAdded,
  });

  @override
  State<EvidenceCapturePage> createState() => _EvidenceCapturePageState();
}

class _EvidenceCapturePageState extends State<EvidenceCapturePage> {
  final _cameraService = CameraCaptureService();
  final _uploadRepository = GetIt.instance<EvidenceUploadRepository>();
  CapturedEvidence? _evidence;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final initialized = await CameraCaptureService.initializeCamera();
      if (!initialized) {
        _showError('Camera initialization failed');
      }
    } catch (e) {
      appLogger.e('Camera init error', error: e);
    }
  }

  Future<void> _capturePhoto() async {
    setState(() => _isLoading = true);
    try {
      final evidence = await _cameraService.capturePhoto(
        includeGps: true,
        autoCompress: true,
      );

      if (evidence != null) {
        setState(() => _evidence = evidence);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _captureVideo() async {
    setState(() => _isLoading = true);
    try {
      final evidence = await _cameraService.captureVideo(
        includeGps: true,
        maxDuration: const Duration(minutes: 5),
      );

      if (evidence != null) {
        setState(() => _evidence = evidence);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);
    try {
      // Show gallery picker dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select from Gallery'),
          content: const Text('Choose photo or video'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'photo'),
              child: const Text('Photo'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'video'),
              child: const Text('Video'),
            ),
          ],
        ),
      );

      if (result == 'photo') {
        final evidence = await _cameraService.pickImageFromGallery();
        if (evidence != null) setState(() => _evidence = evidence);
      } else if (result == 'video') {
        final evidence = await _cameraService.pickVideoFromGallery();
        if (evidence != null) setState(() => _evidence = evidence);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _retakeEvidence() {
    setState(() => _evidence = null);
  }

  Future<void> _submitEvidence() async {
    if (_evidence == null) {
      _showError('No evidence selected');
      return;
    }

    if (!_evidence!.isReadyForSubmit) {
      _showError('Please add a description');
      return;
    }

    setState(() => _isLoading = true);
    try {
      appLogger.i('📤 Submitting evidence: ${_evidence!.fileName}');

      // Step 1: Initialize upload and get signed URL
      appLogger.d('📨 Initializing upload...');
      final initResult = await _uploadRepository.uploadInit(
        activityId: widget.activityId,
        mimeType: _evidence!.mimeType,
        sizeBytes: _evidence!.sizeBytes,
        fileName: _evidence!.fileName,
      );
      appLogger.d('✅ Upload initialized: ${initResult.evidenceId}');

      // Step 2: Read file bytes and PUT to signed URL
      appLogger.d('📤 Uploading file to GCS...');
      final file = File(_evidence!.localPath);
      final bytes = await file.readAsBytes();

      await _uploadRepository.uploadBytesToSignedUrl(
        signedUrl: initResult.signedUrl,
        bytes: bytes,
        mimeType: _evidence!.mimeType,
      );
      appLogger.d('✅ File uploaded to GCS (${bytes.length} bytes)');

      // Step 3: Finalize upload
      appLogger.d('🏁 Finalizing upload...');
      await _uploadRepository.uploadComplete(
        evidenceId: initResult.evidenceId,
        description: _evidence?.description,
      );
      appLogger.i(
        '✅ Evidence submitted successfully: ${initResult.evidenceId}',
      );

      if (mounted) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Evidencia enviada — ID: ${initResult.evidenceId.substring(0, 8)}…',
            backgroundColor: SaoColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onEvidenceAdded?.call();
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      // Network errors: queue for offline retry
      appLogger.w('Network error during upload: ${e.message}');
      await _handleNetworkError(e);
    } catch (e) {
      _showError('No se pudo enviar la evidencia: $e');
      appLogger.e('Upload error', error: e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleNetworkError(DioException error) async {
    try {
      appLogger.i('Queuing evidence for offline retry...');

      // Queue for offline retry
      final queueId = await _uploadRepository.enqueuePendingUpload(
        activityId: widget.activityId,
        localPath: _evidence!.localPath,
        fileName: _evidence!.fileName,
        mimeType: _evidence!.mimeType,
        sizeBytes: _evidence!.sizeBytes,
        description: _evidence!.description,
      );

      if (mounted) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Sin conexión — evidencia en cola (ID: ${queueId.substring(0, 8)}…)',
            backgroundColor: SaoColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
        widget.onEvidenceAdded?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('No se pudo encolar la evidencia: $e');
      appLogger.e('Offline queue error', error: e);
    }
  }

  void _showError(String message) {
    showTransientSnackBar(
      context,
      appSnackBar(message: message, backgroundColor: SaoColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_evidence == null) {
      return _buildCaptureSelection();
    } else {
      return _buildEvidenceReview();
    }
  }

  Widget _buildCaptureSelection() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Evidence'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Camera capture section
                Card(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.camera_alt,
                          size: 48,
                          color: SaoColors.primary,
                        ),
                      ),
                      const Text(
                        'Capture Photo',
                        style: SaoTypography.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a photo using the device camera',
                        style: SaoTypography.bodySmall.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _capturePhoto,
                        icon: const Icon(Icons.camera),
                        label: const Text('Take Photo'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Video capture section
                Card(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.videocam,
                          size: 48,
                          color: SaoColors.primary,
                        ),
                      ),
                      const Text(
                        'Capture Video',
                        style: SaoTypography.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record a video (max 5 minutes)',
                        style: SaoTypography.bodySmall.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _captureVideo,
                        icon: const Icon(Icons.videocam),
                        label: const Text('Record Video'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Gallery picker section
                Card(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: SaoColors.primary,
                        ),
                      ),
                      const Text(
                        'Choose from Gallery',
                        style: SaoTypography.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select an existing photo or video',
                        style: SaoTypography.bodySmall.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose from Gallery'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEvidenceReview() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Evidence'),
        actions: [
          TextButton.icon(
            onPressed: _retakeEvidence,
            icon: const Icon(Icons.edit),
            label: const Text('Retake'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview
          EvidencePreviewCard(evidence: _evidence!),
          const SizedBox(height: 24),

          // GPS location if available
          if (_evidence!.gpsLocation != null) ...[
            GpsLocationDisplay(location: _evidence!.gpsLocation!),
            const SizedBox(height: 24),
          ],

          // Compression stats if compressed
          if (_evidence!.isCompressed && _evidence!.compressionStats != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Compression', style: SaoTypography.labelMedium),
                    const SizedBox(height: 8),
                    Text(
                      _evidence!.compressionStats!.toString(),
                      style: SaoTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Description form
          EvidenceDescriptionForm(
            evidence: _evidence!,
            onDescriptionChanged: (desc) {
              setState(() {
                _evidence = _evidence!.copyWith(description: desc);
              });
            },
          ),
          const SizedBox(height: 24),

          // Submit button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submitEvidence,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Submit Evidence'),
          ),
        ],
      ),
    );
  }
}
