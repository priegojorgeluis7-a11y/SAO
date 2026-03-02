// test/features/evidence/evidence_capture_test.dart
// Tests for evidence capture services and models.

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/evidence/services/camera_capture_service.dart';
import 'package:sao_windows/features/evidence/services/gps_tagging_service.dart';
import 'package:sao_windows/features/evidence/services/image_compression_service.dart';

void main() {
  group('CapturedEvidence Model', () {
    test('creates evidence with basic properties', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      expect(evidence.localPath, '/storage/photo.jpg');
      expect(evidence.displayName, 'photo.jpg');
      expect(evidence.mimeType, 'image/jpeg');
      expect(evidence.isReadyForSubmit, false); // No description yet
    });

    test('checks if ready for submission', () {
      var evidence = const CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1048576,
        description: '',
      );

      expect(evidence.isReadyForSubmit, false);

      evidence = evidence.copyWith(description: 'Test description');
      expect(evidence.isReadyForSubmit, true);

      evidence = evidence.copyWith(description: '   '); // Whitespace only
      expect(evidence.isReadyForSubmit, false);
    });

    test('formats file size correctly', () {
      expect(
        const CapturedEvidence(
          localPath: '',
          fileName: 'file.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 512,
        ).fileSizeDisplay,
        '512 B',
      );

      expect(
        const CapturedEvidence(
          localPath: '',
          fileName: 'file2.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1048576,
        ).fileSizeDisplay,
        '1.0 MB',
      );
    });

    test('serializes and deserializes to/from JSON', () {
      const original = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        description: 'Test photo',
      );

      final json = original.toJson();
      expect(json['fileName'], 'photo.jpg');
      expect(json['description'], 'Test photo');
      expect(json['sizeBytes'], 2048000);
    });

    test('handles GPS location tagging', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
        altitude: 52.3,
      );

      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        gpsLocation: location,
      );

      expect(evidence.gpsDisplay, '37.7749,-122.4194');
      expect(evidence.gpsLocation!.accuracy, 10.5);
    });

    test('handles compression stats', () {
      final stats = CompressionStats(
        originalSizeBytes: 4000000,
        compressedSizeBytes: 1000000,
        processingTime: const Duration(milliseconds: 500),
      );

      expect(stats.compressionRatio, closeTo(0.75, 0.01));
      expect(stats.percentReduction, closeTo(75.0, 1.0));
    });
  });

  group('GpsLocation Model', () {
    test('calculates distance between two locations', () {
      const sanFrancisco = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      const losAngeles = GpsLocation(
        latitude: 34.0522,
        longitude: -118.2437,
      );

      final distance = sanFrancisco.distanceTo(losAngeles);
      expect(distance, greaterThan(500000)); // > 500km
      expect(distance, lessThan(600000)); // < 600km
    });

    test('formats location to string', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
      );

      final shortString = location.toShortString();
      expect(shortString, '37.7749,-122.4194');

      final fullString = location.toString();
      expect(fullString, contains('37.7749'));
      expect(fullString, contains('122.4194'));
      expect(fullString, contains('10.5'));
    });

    test('serializes and deserializes location', () {
      const original = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
        altitude: 52.3,
      );

      final json = original.toJson();
      final restored = GpsLocation.fromJson(json);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.accuracy, original.accuracy);
      expect(restored.altitude, original.altitude);
    });

    test('checks if location is within radius', () {
      const center = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      const nearPoint = GpsLocation(
        latitude: 37.7750,
        longitude: -122.4195,
      );

      const farPoint = GpsLocation(
        latitude: 34.0522,
        longitude: -118.2437,
      );

      expect(
        GpsTaggingService.isWithinRadius(
          subject: nearPoint,
          centerPoint: center,
          radiusMeters: 500,
        ),
        true,
      );

      expect(
        GpsTaggingService.isWithinRadius(
          subject: farPoint,
          centerPoint: center,
          radiusMeters: 500,
        ),
        false,
      );
    });

    test('calculates center point of locations', () {
      final locations = [
        const GpsLocation(latitude: 37.7749, longitude: -122.4194),
        const GpsLocation(latitude: 34.0522, longitude: -118.2437),
        const GpsLocation(latitude: 40.7128, longitude: -74.0060), // NYC
      ];

      final center = GpsTaggingService.calculateCenterPoint(locations);
      expect(center, isNotNull);
      expect(center!.latitude, lessThan(40.8));
      expect(center.latitude, greaterThan(34.0));
    });
  });

  group('ImageCompressionService', () {
    test('formats file size correctly', () {
      expect(ImageCompressionService.formatFileSize(512), '512 B');
      expect(ImageCompressionService.formatFileSize(1024), '1.0 KB');
      expect(ImageCompressionService.formatFileSize(1048576), '1.0 MB');
      expect(ImageCompressionService.formatFileSize(1073741824), '1.0 GB');
    });

    test('parses file sizes correctly', () {
      expect(ImageCompressionService.formatFileSize(2048), '2.0 KB');
      expect(ImageCompressionService.formatFileSize(5242880), '5.0 MB');
      expect(ImageCompressionService.formatFileSize(10737418240), '10.0 GB');
    });
  });

  group('CompressionStats', () {
    test('calculates compression metrics', () {
      final stats = CompressionStats(
        originalSizeBytes: 4000000,
        compressedSizeBytes: 1000000,
        processingTime: const Duration(milliseconds: 500),
      );

      expect(stats.compressionRatio, 0.75);
      expect(stats.percentReduction, 75.0);
      expect(stats.processingTime.inMilliseconds, 500);
    });

    test('formats compression stats to string', () {
      final stats = CompressionStats(
        originalSizeBytes: 4000000,
        compressedSizeBytes: 1000000,
        processingTime: const Duration(milliseconds: 500),
      );

      final str = stats.toString();
      expect(str, contains('4000000'));
      expect(str, contains('1000000'));
      expect(str, contains('75.0%'));
    });

    test('handles no compression case', () {
      final stats = CompressionStats(
        originalSizeBytes: 1000000,
        compressedSizeBytes: 1000000,
        processingTime: const Duration(milliseconds: 100),
      );

      expect(stats.compressionRatio, 0.0);
      expect(stats.percentReduction, 0.0);
    });
  });

  group('Evidence Capture Workflow', () {
    test('creates valid evidence for submission', () {
      var evidence = const CapturedEvidence(
        localPath: '/storage/activities/activity-123/photo.jpg',
        fileName: 'activity_photo_001.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      // Not ready until description added
      expect(evidence.isReadyForSubmit, false);

      // Add description
      evidence = evidence.copyWith(description: 'Photo of the site perimeter');
      expect(evidence.isReadyForSubmit, true);

      // Can be used for upload
      final values = evidence.toJson();
      expect(values['description'], 'Photo of the site perimeter');
      expect(values['mimeType'], 'image/jpeg');
    });

    test('handles multiple evidence pieces with GPS', () {
      const location1 = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      const location2 = GpsLocation(
        latitude: 37.7750,
        longitude: -122.4195,
      );

      const evidence1 = CapturedEvidence(
        localPath: '/storage/photo1.jpg',
        fileName: 'photo1.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1048576,
        gpsLocation: location1,
        description: 'First location',
      );

      const evidence2 = CapturedEvidence(
        localPath: '/storage/photo2.jpg',
        fileName: 'photo2.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1048576,
        gpsLocation: location2,
        description: 'Second location',
      );

      expect(evidence1.isReadyForSubmit, true);
      expect(evidence2.isReadyForSubmit, true);

      final distance = evidence1.gpsLocation!.distanceTo(evidence2.gpsLocation!);
      expect(distance, lessThan(200)); // Should be very close
    });
  });
}
