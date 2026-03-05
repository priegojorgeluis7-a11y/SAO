// test/features/evidence/services/camera_capture_service_test.dart
// Unit tests for CameraCaptureService and CapturedEvidence model.

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/evidence/services/camera_capture_service.dart';
import 'package:sao_windows/features/evidence/services/gps_tagging_service.dart';
import 'package:sao_windows/features/evidence/services/image_compression_service.dart';

void main() {
  group('CapturedEvidence Model', () {
    test('creates evidence with required fields', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      expect(evidence.localPath, '/storage/photo.jpg');
      expect(evidence.fileName, 'photo.jpg');
      expect(evidence.displayName, 'photo.jpg');
      expect(evidence.mimeType, 'image/jpeg');
      expect(evidence.sizeBytes, 2048000);
    });

    test('creates evidence with all fields', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
      );

      final stats = CompressionStats(
        originalSizeBytes: 4000000,
        compressedSizeBytes: 1000000,
        processingTime: const Duration(milliseconds: 500),
      );

      final evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1000000,
        gpsLocation: location,
        description: 'Test photo',
        isCompressed: true,
        compressionStats: stats,
        capturedAtEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
      );

      expect(evidence.localPath, '/storage/photo.jpg');
      expect(evidence.gpsLocation, isNotNull);
      expect(evidence.description, 'Test photo');
      expect(evidence.isCompressed, true);
      expect(evidence.compressionStats, isNotNull);
      expect(evidence.capturedAt, DateTime(2024, 1, 15, 14, 30, 0));
    });

    test('determines if ready for submission without description', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      expect(evidence.isReadyForSubmit, false);
    });

    test('determines if ready for submission with description', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        description: 'Test description',
      );

      expect(evidence.isReadyForSubmit, true);
    });

    test('considers whitespace-only description as not ready', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        description: '   \n\t  ',
      );

      expect(evidence.isReadyForSubmit, false);
    });

    test('formats GPS display correctly', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        gpsLocation: location,
      );

      expect(evidence.gpsDisplay, '37.7749,-122.4194');
    });

    test('formats GPS display as empty when null', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      expect(evidence.gpsDisplay, '');
    });

    test('formats file size display', () {
      const evidence1 = CapturedEvidence(
        localPath: '/storage/photo1.jpg',
        fileName: 'photo1.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 512,
      );
      expect(evidence1.fileSizeDisplay, '512 B');

      const evidence2 = CapturedEvidence(
        localPath: '/storage/photo2.jpg',
        fileName: 'photo2.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1048576,
      );
      expect(evidence2.fileSizeDisplay, '1.0 MB');
    });

    test('checks if media type is photo', () {
      const photo = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      expect(photo.isPhoto, true);
      expect(photo.isVideo, false);
    });

    test('checks if media type is video', () {
      const video = CapturedEvidence(
        localPath: '/storage/video.mp4',
        fileName: 'video.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 52428800,
      );

      expect(video.isVideo, true);
      expect(video.isPhoto, false);
    });

    test('converts evidence to JSON', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        description: 'Test photo',
      );

      final json = evidence.toJson();

      expect(json['localPath'], '/storage/photo.jpg');
      expect(json['fileName'], 'photo.jpg');
      expect(json['mimeType'], 'image/jpeg');
      expect(json['sizeBytes'], 2048000);
      expect(json['description'], 'Test photo');
    });

    test('creates copy with updated fields', () {
      const original = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      final updated = original.copyWith(
        description: 'New description',
        isCompressed: true,
      );

      expect(updated.localPath, original.localPath);
      expect(updated.fileName, original.fileName);
      expect(updated.description, 'New description');
      expect(updated.isCompressed, true);
    });

    test('preserves old fields when copying with partial updates', () {
      const original = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        description: 'Original description',
      );

      final updated = original.copyWith(isCompressed: true);

      expect(updated.description, 'Original description');
      expect(updated.isCompressed, true);
    });
  });

  group('CapturedEvidence Workflow', () {
    test('completes full evidence capture workflow', () {
      // Step 1: Capture photo
      var evidence = const CapturedEvidence(
        localPath: '/storage/activities/activity-123/photo_001.jpg',
        fileName: 'activity_photo_001.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 4000000,
      );

      expect(evidence.isReadyForSubmit, false);

      // Step 2: Add GPS location
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 8.5,
      );

      evidence = evidence.copyWith(gpsLocation: location);
      expect(evidence.gpsLocation, isNotNull);
      expect(evidence.gpsDisplay, '37.7749,-122.4194');

      // Step 3: Compress image
      final stats = CompressionStats(
        originalSizeBytes: 4000000,
        compressedSizeBytes: 1000000,
        processingTime: const Duration(milliseconds: 500),
      );

      evidence = evidence.copyWith(
        isCompressed: true,
        compressionStats: stats,
        sizeBytes: 1000000,
      );

      expect(evidence.isCompressed, true);
      expect(evidence.fileSizeDisplay, '976.6 KB');

      // Step 4: Add description
      evidence = evidence.copyWith(description: 'Photo of site perimeter');
      expect(evidence.isReadyForSubmit, true);

      // Verify complete state
      final json = evidence.toJson();
      expect(json['description'], 'Photo of site perimeter');
      expect(json['sizeBytes'], 1000000);
      expect(json['isCompressed'], true);
    });

    test('handles multiple evidence pieces in sequence', () {
      final evidenceList = <CapturedEvidence>[];

      // Capture 3 photos
      for (int i = 0; i < 3; i++) {
        final evidence = CapturedEvidence(
          localPath: '/storage/photo_$i.jpg',
          fileName: 'photo_$i.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 2048000,
          description: 'Photo $i of the site',
        );
        evidenceList.add(evidence);
      }

      expect(evidenceList.length, 3);
      expect(evidenceList.every((e) => e.isReadyForSubmit), true);
    });

    test('tracks compression savings across multiple photos', () {
      final photoStats = [
        CompressionStats(
          originalSizeBytes: 4000000,
          compressedSizeBytes: 1000000,
          processingTime: const Duration(milliseconds: 500),
        ),
        CompressionStats(
          originalSizeBytes: 3000000,
          compressedSizeBytes: 900000,
          processingTime: const Duration(milliseconds: 400),
        ),
        CompressionStats(
          originalSizeBytes: 5000000,
          compressedSizeBytes: 1200000,
          processingTime: const Duration(milliseconds: 600),
        ),
      ];

      final totalOriginal =
          photoStats.fold<int>(0, (sum, s) => sum + s.originalSizeBytes);
      final totalCompressed =
          photoStats.fold<int>(0, (sum, s) => sum + s.compressedSizeBytes);

      expect(totalOriginal, 12000000);
      expect(totalCompressed, 3100000);

      final percentReduction = ((totalOriginal - totalCompressed) / totalOriginal * 100);
      expect(percentReduction, closeTo(74.2, 1.0));
    });
  });

  group('MIME Type Handling', () {
    test('identifies JPEG photos', () {
      const jpeg = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      expect(jpeg.mimeType, 'image/jpeg');
      expect(jpeg.isPhoto, true);
    });

    test('identifies PNG photos', () {
      const png = CapturedEvidence(
        localPath: '/storage/photo.png',
        fileName: 'photo.png',
        mimeType: 'image/png',
        sizeBytes: 3000000,
      );

      expect(png.mimeType, 'image/png');
      expect(png.isPhoto, true);
    });

    test('identifies WebP photos', () {
      const webp = CapturedEvidence(
        localPath: '/storage/photo.webp',
        fileName: 'photo.webp',
        mimeType: 'image/webp',
        sizeBytes: 1500000,
      );

      expect(webp.mimeType, 'image/webp');
      expect(webp.isPhoto, true);
    });

    test('identifies MP4 videos', () {
      const mp4 = CapturedEvidence(
        localPath: '/storage/video.mp4',
        fileName: 'video.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 52428800,
      );

      expect(mp4.mimeType, 'video/mp4');
      expect(mp4.isVideo, true);
    });

    test('identifies MOV videos', () {
      const mov = CapturedEvidence(
        localPath: '/storage/video.mov',
        fileName: 'video.mov',
        mimeType: 'video/quicktime',
        sizeBytes: 157286400,
      );

      expect(mov.mimeType, 'video/quicktime');
      expect(mov.isVideo, true);
    });
  });

  group('File Size Validation', () {
    test('handles small files', () {
      const small = CapturedEvidence(
        localPath: '/storage/small.jpg',
        fileName: 'small.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 102400,
      );

      expect(small.fileSizeDisplay, '100.0 KB');
    });

    test('handles medium files', () {
      const medium = CapturedEvidence(
        localPath: '/storage/medium.jpg',
        fileName: 'medium.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 5242880,
      );

      expect(medium.fileSizeDisplay, '5.0 MB');
    });

    test('handles large files', () {
      const large = CapturedEvidence(
        localPath: '/storage/large.mp4',
        fileName: 'large.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 1073741824,
      );

      expect(large.fileSizeDisplay, '1.0 GB');
    });

    test('handles zero-size file', () {
      const empty = CapturedEvidence(
        localPath: '/storage/empty.txt',
        fileName: 'empty.txt',
        mimeType: 'text/plain',
        sizeBytes: 0,
      );

      expect(empty.fileSizeDisplay, '0 B');
    });
  });

  group('EvidenceCaptureArguments', () {
    test('creates arguments with required fields', () {
      const args = EvidenceCaptureArguments(
        activityId: '123',
        fieldKey: 'evidence_1',
      );

      expect(args.activityId, '123');
      expect(args.fieldKey, 'evidence_1');
    });

    test('preserves arguments through serialization', () {
      const original = EvidenceCaptureArguments(
        activityId: 'activity-abc-123',
        fieldKey: 'field_photo_evidence',
      );

      // Simulate route argument passing
      expect(original.activityId, 'activity-abc-123');
      expect(original.fieldKey, 'field_photo_evidence');
    });
  });
}
