// lib/features/evidence/services/camera_capture_service.dart
// Service for capturing photos and videos with metadata.
// Integrates camera, GPS tagging, and file compression.

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/logger.dart';
import 'gps_tagging_service.dart';
import 'image_compression_service.dart';

class EvidenceCaptureArguments {
  final String activityId;
  final String? fieldKey;

  const EvidenceCaptureArguments({
    required this.activityId,
    this.fieldKey,
  });
}

class CapturedEvidence {
  /// Local file path of the captured image/video
  final String localPath;

  /// File name without path
  final String fileName;

  /// MIME type (image/jpeg, image/png, video/mp4, etc.)
  final String mimeType;

  /// File size in bytes
  final int sizeBytes;

  /// GPS location when photo was taken
  final GpsLocation? gpsLocation;

  /// User description/notes for the evidence
  final String description;

  /// Whether this has been compressed
  final bool isCompressed;

  /// Compression stats if applicable
  final CompressionStats? compressionStats;

  /// Timestamp when captured (epoch millis for const compatibility)
  final int? capturedAtEpochMs;

  DateTime? get capturedAt {
    final value = capturedAtEpochMs;
    if (value == null || value <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  const CapturedEvidence({
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.gpsLocation,
    this.description = '',
    this.isCompressed = false,
    this.compressionStats,
    this.capturedAtEpochMs,
  });

  /// Get display name
  String get displayName => fileName.split('/').last;

  /// Get human-readable file size
  String get fileSizeDisplay => ImageCompressionService.formatFileSize(sizeBytes);

  /// Get GPS location string for display
  String get gpsDisplay => gpsLocation?.toShortString() ?? '';

  /// Whether evidence is ready to submit (has description)
  bool get isReadyForSubmit => sizeBytes > 0 && description.trim().isNotEmpty;

  bool get isPhoto => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');

  CapturedEvidence copyWith({
    String? localPath,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    GpsLocation? gpsLocation,
    String? description,
    bool? isCompressed,
    CompressionStats? compressionStats,
    DateTime? capturedAt,
    int? capturedAtEpochMs,
  }) {
    return CapturedEvidence(
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      description: description ?? this.description,
      isCompressed: isCompressed ?? this.isCompressed,
      compressionStats: compressionStats ?? this.compressionStats,
      capturedAtEpochMs: capturedAtEpochMs ?? capturedAt?.millisecondsSinceEpoch ?? this.capturedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'localPath': localPath,
        'fileName': fileName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'gpsLocation': gpsLocation?.toJson(),
        'description': description,
        'isCompressed': isCompressed,
        'capturedAt': capturedAt?.toIso8601String(),
      };
}

class CameraCaptureService {
  final ImagePicker _picker = ImagePicker();

  /// Initialize camera permissions and check availability.
  static Future<bool> initializeCamera() async {
    try {
      appLogger.i('📷 Initializing camera...');

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        appLogger.w('⚠️ No cameras available');
        return false;
      }

      appLogger.i('✅ Camera initialized: ${cameras.length} camera(s) found');
      return true;
    } catch (e, stack) {
      appLogger.e('❌ Camera initialization failed', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Capture a photo using device camera.
  Future<CapturedEvidence?> capturePhoto({
    bool includeGps = true,
    bool autoCompress = true,
  }) async {
    try {
      appLogger.i('📷 Opening camera to capture photo...');

      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo == null) {
        appLogger.i('ℹ️ Photo capture cancelled');
        return null;
      }

      // Get GPS location if requested
      GpsLocation? gpsLocation;
      if (includeGps) {
        gpsLocation = await GpsTaggingService.getCurrentLocation();
        if (gpsLocation != null) {
          appLogger.i('✅ GPS location captured: ${gpsLocation.toShortString()}');
        }
      }

      // Get file info
      final file = File(photo.path);
      final bytes = await file.readAsBytes();
      final sizeBytes = bytes.length;

      var evidence = CapturedEvidence(
        localPath: photo.path,
        fileName: photo.name,
        mimeType: 'image/jpeg',
        sizeBytes: sizeBytes,
        gpsLocation: gpsLocation,
        capturedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      appLogger.i('✅ Photo captured: ${evidence.fileSizeDisplay}');

      // Auto-compress if requested
      if (autoCompress) {
        evidence = await _compressEvidence(evidence);
      }

      return evidence;
    } catch (e, stack) {
      appLogger.e('❌ Photo capture failed', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Capture a video using device camera.
  Future<CapturedEvidence?> captureVideo({
    bool includeGps = true,
    Duration? maxDuration,
  }) async {
    try {
      appLogger.i('🎥 Opening camera to capture video...');

      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
      );

      if (video == null) {
        appLogger.i('ℹ️ Video capture cancelled');
        return null;
      }

      // Get GPS location if requested
      GpsLocation? gpsLocation;
      if (includeGps) {
        gpsLocation = await GpsTaggingService.getCurrentLocation();
      }

      // Get file info
      final file = File(video.path);
      final bytes = await file.readAsBytes();
      final sizeBytes = bytes.length;

      final evidence = CapturedEvidence(
        localPath: video.path,
        fileName: video.name,
        mimeType: 'video/mp4',
        sizeBytes: sizeBytes,
        gpsLocation: gpsLocation,
        capturedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      appLogger.i('✅ Video captured: ${evidence.fileSizeDisplay}');
      return evidence;
    } catch (e, stack) {
      appLogger.e('❌ Video capture failed', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Pick an existing image from gallery.
  Future<CapturedEvidence?> pickImageFromGallery({
    bool autoCompress = true,
  }) async {
    try {
      appLogger.i('🖼️ Opening gallery to pick image...');

      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        appLogger.i('ℹ️ Gallery pick cancelled');
        return null;
      }

      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final sizeBytes = bytes.length;

      var evidence = CapturedEvidence(
        localPath: image.path,
        fileName: image.name,
        mimeType: _getMimeType(image.path),
        sizeBytes: sizeBytes,
        capturedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      appLogger.i('✅ Image picked from gallery: ${evidence.fileSizeDisplay}');

      if (autoCompress) {
        evidence = await _compressEvidence(evidence);
      }

      return evidence;
    } catch (e, stack) {
      appLogger.e('❌ Gallery pick failed', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Pick an existing video from gallery.
  Future<CapturedEvidence?> pickVideoFromGallery() async {
    try {
      appLogger.i('🎬 Opening gallery to pick video...');

      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) {
        appLogger.i('ℹ️ Video pick cancelled');
        return null;
      }

      final file = File(video.path);
      final bytes = await file.readAsBytes();
      final sizeBytes = bytes.length;

      final evidence = CapturedEvidence(
        localPath: video.path,
        fileName: video.name,
        mimeType: 'video/mp4',
        sizeBytes: sizeBytes,
        capturedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      appLogger.i('✅ Video picked from gallery: ${evidence.fileSizeDisplay}');
      return evidence;
    } catch (e, stack) {
      appLogger.e('❌ Video gallery pick failed', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Compress evidence file and return new CapturedEvidence with compressed path.
  Future<CapturedEvidence> _compressEvidence(CapturedEvidence evidence) async {
    if (!evidence.mimeType.startsWith('image/')) {
      return evidence; // Only compress images for now
    }

    try {
      appLogger.i('🗜️ Compressing evidence: ${evidence.fileSizeDisplay}');

      final stats = await ImageCompressionService.compressImage(
        inputPath: evidence.localPath,
        quality: 75,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (stats.compressedSizeBytes >= evidence.sizeBytes) {
        appLogger.i('⏭️ Compression not beneficial, keeping original');
        return evidence;
      }

      return CapturedEvidence(
        localPath: evidence.localPath.replaceFirst('.jpg', '_compressed.jpg'),
        fileName: evidence.fileName,
        mimeType: evidence.mimeType,
        sizeBytes: stats.compressedSizeBytes,
        gpsLocation: evidence.gpsLocation,
        description: evidence.description,
        isCompressed: true,
        compressionStats: stats,
        capturedAtEpochMs: evidence.capturedAtEpochMs,
      );
    } catch (e, stack) {
      appLogger.e('❌ Compression failed, using original', error: e, stackTrace: stack);
      return evidence;
    }
  }

  /// Get MIME type from file extension.
  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }
}
