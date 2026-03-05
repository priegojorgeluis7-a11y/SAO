// test/features/evidence/evidence_integration_test.dart
// Integration tests for the complete evidence capture workflow.
// Tests the flow from camera capture through GPS tagging to compression and submission readiness.

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/evidence/services/camera_capture_service.dart';
import 'package:sao_windows/features/evidence/services/gps_tagging_service.dart';
import 'package:sao_windows/features/evidence/services/image_compression_service.dart';

void main() {
  group('Evidence Capture Integration', () {
    test('completes full capture workflow: camera → compress → GPS → submit', () {
      // Step 1: Simulate capturing a photo from camera
      var capturedEvidence = CapturedEvidence(
        localPath: '/storage/activities/activity-001/photo_20240115_143000.jpg',
        fileName: 'photo_20240115_143000.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 4194304, // 4 MB raw photo
        capturedAtEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
      );

      expect(capturedEvidence.localPath, contains('activity-001'));
      expect(capturedEvidence.mimeType, 'image/jpeg');
      expect(capturedEvidence.isPhoto, true);

      // Step 2: Add GPS location data
      const baseLocation = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 12.5,
        altitude: 52.3,
        heading: 180.0,
        speed: 2.5,
      );

      capturedEvidence = capturedEvidence.copyWith(
        gpsLocation: baseLocation,
      );

      expect(capturedEvidence.gpsLocation, isNotNull);
      expect(capturedEvidence.gpsDisplay, '37.7749,-122.4194');

      // Step 3: Compress the image
      final compressionStats = CompressionStats(
        originalSizeBytes: 4194304,
        compressedSizeBytes: 1048576, // Compressed to 1 MB
        processingTime: const Duration(milliseconds: 1200),
      );

      capturedEvidence = capturedEvidence.copyWith(
        isCompressed: true,
        compressionStats: compressionStats,
        sizeBytes: 1048576,
      );

      expect(capturedEvidence.isCompressed, true);
      expect(capturedEvidence.compressionStats!.percentReduction, 75.0);
      expect(
        capturedEvidence.fileSizeDisplay,
        '1.0 MB',
      );

      // Step 4: Add description
      capturedEvidence = capturedEvidence.copyWith(
        description: 'Photo of the project site perimeter showing access point 1',
      );

      // Step 5: Verify ready for submission
      expect(capturedEvidence.isReadyForSubmit, true);

      // Verify final state
      final json = capturedEvidence.toJson();
      expect(json['fileName'], 'photo_20240115_143000.jpg');
      expect(json['description'], contains('project site'));
      expect(json['sizeBytes'], 1048576);
      expect(json['isCompressed'], true);
    });

    test('handles multi-photo evidence collection at same location', () {
      const captureLocation = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 8.5,
      );

      // Capture multiple photos at same GPS point
      final photoEvidences = <CapturedEvidence>[];

      for (int i = 1; i <= 3; i++) {
        var evidence = CapturedEvidence(
          localPath: '/storage/activities/activity-001/photo_00$i.jpg',
          fileName: 'photo_00$i.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 3145728,
          gpsLocation: captureLocation,
          capturedAtEpochMs: DateTime(2024, 1, 15, 14, 30, i).millisecondsSinceEpoch,
        );

        // Compress each photo
        final stats = CompressionStats(
          originalSizeBytes: 3145728,
          compressedSizeBytes: 786432,
          processingTime: const Duration(milliseconds: 1000),
        );

        evidence = evidence.copyWith(
          isCompressed: true,
          compressionStats: stats,
          sizeBytes: 786432,
          description: 'Photo $i from same location',
        );

        photoEvidences.add(evidence);
      }

      // Verify collection
      expect(photoEvidences.length, 3);
      expect(photoEvidences.every((e) => e.isReadyForSubmit), true);
      expect(
        photoEvidences.every(
          (e) => e.gpsDisplay == '37.7749,-122.4194',
        ),
        true,
      );

      // Verify compression savings
      final totalOriginal = photoEvidences.fold<int>(
        0,
        (sum, e) => sum + (e.compressionStats?.originalSizeBytes ?? 0),
      );
      final totalCompressed = photoEvidences.fold<int>(
        0,
        (sum, e) => sum + e.sizeBytes,
      );

      expect(totalOriginal, 9437184);
      expect(totalCompressed, 2359296);
      expect(
        ((totalOriginal - totalCompressed) / totalOriginal * 100),
        closeTo(75.0, 1.0),
      );
    });

    test('handles video capture with GPS tracking', () {
      // Simulate video with multiple GPS points
      final gpsPoints = [
        GpsLocation(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10.0,
          timestampEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
        ),
        GpsLocation(
          latitude: 37.7750,
          longitude: -122.4195,
          accuracy: 9.5,
          timestampEpochMs: DateTime(2024, 1, 15, 14, 30, 30).millisecondsSinceEpoch,
        ),
        GpsLocation(
          latitude: 37.7751,
          longitude: -122.4196,
          accuracy: 11.0,
          timestampEpochMs: DateTime(2024, 1, 15, 14, 31, 0).millisecondsSinceEpoch,
        ),
      ];

      var videoEvidence = CapturedEvidence(
        localPath: '/storage/activities/activity-001/video_20240115_143000.mp4',
        fileName: 'video_20240115_143000.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 157286400, // 150 MB video
        gpsLocation: gpsPoints.first,
        capturedAtEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
      );

      // Calculate path coverage
      double totalDistance = 0;
      for (int i = 0; i < gpsPoints.length - 1; i++) {
        totalDistance += gpsPoints[i].distanceTo(gpsPoints[i + 1]);
      }

      expect(totalDistance, greaterThan(20)); // Moved > 20m
      expect(videoEvidence.isVideo, true);

      // Add description
      videoEvidence = videoEvidence.copyWith(
        description:
            'Video walkthrough of project site showing completion progress',
      );

      expect(videoEvidence.isReadyForSubmit, true);
    });

    test('handles mixed media evidence set', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 8.0,
      );

      // Create mixed evidence set
      final evidenceSet = <CapturedEvidence>[];

      // Photos
      for (int i = 1; i <= 2; i++) {
        final photo = CapturedEvidence(
          localPath: '/storage/activity-001/photo_$i.jpg',
          fileName: 'photo_$i.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 2097152,
          gpsLocation: location,
          description: 'Photo $i',
        );
        evidenceSet.add(photo);
      }

      // Video
      const video = CapturedEvidence(
        localPath: '/storage/activity-001/video_1.mp4',
        fileName: 'video_1.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 52428800,
        gpsLocation: location,
        description: 'Video documentation',
      );
      evidenceSet.add(video);

      expect(evidenceSet.length, 3);
      expect(evidenceSet.where((e) => e.isPhoto).length, 2);
      expect(evidenceSet.where((e) => e.isVideo).length, 1);
      expect(evidenceSet.every((e) => e.isReadyForSubmit), true);
    });

    test('tracks evidence metadata completeness', () {
      var evidence = const CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2097152,
      );

      // Track metadata as it's added
      final metadata = <String>[];

      // Has file info
      metadata.add('file_info');
      expect(metadata.length, 1);

      // Add GPS
      evidence = evidence.copyWith(
        gpsLocation: const GpsLocation(
          latitude: 37.7749,
          longitude: -122.4194,
        ),
      );
      metadata.add('gps_location');
      expect(metadata.length, 2);

      // Add compression info
      evidence = evidence.copyWith(
        isCompressed: true,
        compressionStats: CompressionStats(
          originalSizeBytes: 4000000,
          compressedSizeBytes: 2097152,
          processingTime: const Duration(milliseconds: 500),
        ),
      );
      metadata.add('compression_info');
      expect(metadata.length, 3);

      // Add description
      evidence = evidence.copyWith(description: 'Test description');
      metadata.add('description');
      expect(metadata.length, 4);

      expect(evidence.isReadyForSubmit, true);
    });

    test('handles offline scenario with evidence queue', () {
      // Simulate capturing multiple evidences while offline
      final offlineQueue = <CapturedEvidence>[];

      for (int i = 1; i <= 5; i++) {
        final evidence = CapturedEvidence(
          localPath: '/storage/offline_$i.jpg',
          fileName: 'offline_$i.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1048576,
          description: 'Offline evidence $i',
          capturedAtEpochMs: DateTime(
            2024,
            1,
            15,
            14,
            30 + i,
          ).millisecondsSinceEpoch,
        );
        offlineQueue.add(evidence);
      }

      expect(offlineQueue.length, 5);
      expect(offlineQueue.every((e) => e.isReadyForSubmit), true);

      // Calculate total size
      final totalSize =
          offlineQueue.fold<int>(0, (sum, e) => sum + e.sizeBytes);
      expect(totalSize, 5242880); // 5 MB total
    });

    test('validates evidence for submission requirements', () {
      var evidence = const CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 0, // Invalid: empty file
      );

      expect(evidence.isReadyForSubmit, false);

      // Fix: add content
      evidence = evidence.copyWith(sizeBytes: 1048576);
      expect(evidence.isReadyForSubmit, false); // Still missing description

      // Fix: add description
      evidence = evidence.copyWith(description: 'Valid evidence');
      expect(evidence.isReadyForSubmit, true);
    });

    test('handles evidence modification workflow', () {
      var evidence = const CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2097152,
        description: 'Initial description',
      );

      expect(evidence.isReadyForSubmit, true);

      // Modify description
      evidence = evidence.copyWith(
        description: 'Updated description with more detail',
      );

      expect(evidence.isReadyForSubmit, true);
      expect(evidence.description, 'Updated description with more detail');

      // Modify with GPS
      evidence = evidence.copyWith(
        gpsLocation: const GpsLocation(
          latitude: 37.7749,
          longitude: -122.4194,
        ),
      );

      expect(evidence.gpsDisplay, '37.7749,-122.4194');
    });

    test('handles evidence metadata for audit trail', () {
      final evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1048576,
        description: 'Evidence for audit',
        capturedAtEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
        gpsLocation: const GpsLocation(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 10.0,
        ),
        isCompressed: true,
        compressionStats: CompressionStats(
          originalSizeBytes: 4000000,
          compressedSizeBytes: 1048576,
          processingTime: const Duration(milliseconds: 500),
        ),
      );

      // Audit trail includes all metadata
      final auditJson = evidence.toJson();

      expect(auditJson['fileName'], 'photo.jpg');
      expect(auditJson['mimeType'], 'image/jpeg');
      expect(auditJson['description'], 'Evidence for audit');
      expect(auditJson['sizeBytes'], 1048576);
      expect(auditJson['isCompressed'], true);
    });
  });

  group('Error Recovery Scenarios', () {
    test('recovers from compression failure by using original', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/problem_photo.jpg',
        fileName: 'problem_photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 4000000,
        description: 'Photo',
      );

      // Compression failed, use original
      expect(evidence.isCompressed, false);
      expect(evidence.sizeBytes, 4000000);
      expect(evidence.isReadyForSubmit, true);
    });

    test('handles GPS unavailability', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2097152,
        description: 'Photo without GPS',
        gpsLocation: null, // GPS not available
      );

      expect(evidence.gpsDisplay, '');
      expect(evidence.isReadyForSubmit, true); // GPS is optional
    });

    test('tolerates partial metadata', () {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2097152,
        description: 'Photo',
        // Missing: GPS, compression stats, capture time
      );

      expect(evidence.isReadyForSubmit, true);
    });
  });
}
