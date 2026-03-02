// test/features/evidence/services/image_compression_service_test.dart
/// Unit tests for ImageCompressionService compression logic and PNG conversion.
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/evidence/services/image_compression_service.dart';

void main() {
  group('ImageCompressionService', () {
    group('formatFileSize', () {
      test('formats bytes correctly', () {
        expect(ImageCompressionService.formatFileSize(0), '0 B');
        expect(ImageCompressionService.formatFileSize(1), '1 B');
        expect(ImageCompressionService.formatFileSize(512), '512 B');
      });

      test('formats kilobytes correctly', () {
        expect(ImageCompressionService.formatFileSize(1024), '1.0 KB');
        expect(ImageCompressionService.formatFileSize(1536), '1.5 KB');
        expect(ImageCompressionService.formatFileSize(5120), '5.0 KB');
      });

      test('formats megabytes correctly', () {
        expect(ImageCompressionService.formatFileSize(1048576), '1.0 MB');
        expect(ImageCompressionService.formatFileSize(2097152), '2.0 MB');
        expect(ImageCompressionService.formatFileSize(10485760), '10.0 MB');
      });

      test('formats gigabytes correctly', () {
        expect(ImageCompressionService.formatFileSize(1073741824), '1.0 GB');
        expect(ImageCompressionService.formatFileSize(5368709120), '5.0 GB');
      });

      test('formats edge cases', () {
        expect(ImageCompressionService.formatFileSize(1023), '1023 B');
        expect(ImageCompressionService.formatFileSize(1025), '1.0 KB');
        expect(ImageCompressionService.formatFileSize(1048575), '1024.0 KB');
      });
    });

    group('CompressionStats', () {
      test('creates compression stats with valid data', () {
        final stats = CompressionStats(
          originalSizeBytes: 4000000,
          compressedSizeBytes: 1000000,
          processingTime: const Duration(milliseconds: 1500),
        );

        expect(stats.originalSizeBytes, 4000000);
        expect(stats.compressedSizeBytes, 1000000);
        expect(stats.processingTime.inMilliseconds, 1500);
      });

      test('calculates compression ratio correctly', () {
        final stats = CompressionStats(
          originalSizeBytes: 10000000,
          compressedSizeBytes: 2500000,
          processingTime: const Duration(seconds: 2),
        );

        expect(stats.compressionRatio, 0.75);
      });

      test('calculates percent reduction correctly', () {
        final stats = CompressionStats(
          originalSizeBytes: 1000000,
          compressedSizeBytes: 700000,
          processingTime: const Duration(milliseconds: 500),
        );

        expect(stats.percentReduction, 30.0);
      });

      test('handles compression stats with minimal change', () {
        final stats = CompressionStats(
          originalSizeBytes: 1000000,
          compressedSizeBytes: 950000,
          processingTime: const Duration(milliseconds: 100),
        );

        expect(stats.compressionRatio, closeTo(0.05, 0.01));
        expect(stats.percentReduction, closeTo(5.0, 1.0));
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

      test('handles worse compression case (expansion)', () {
        final stats = CompressionStats(
          originalSizeBytes: 1000000,
          compressedSizeBytes: 1100000,
          processingTime: const Duration(milliseconds: 100),
        );

        expect(stats.compressionRatio, lessThan(0.0));
        expect(stats.percentReduction, lessThan(0.0));
      });

      test('formats stats to string', () {
        final stats = CompressionStats(
          originalSizeBytes: 4000000,
          compressedSizeBytes: 1000000,
          processingTime: const Duration(milliseconds: 500),
        );

        final str = stats.toString();
        expect(str, contains('4000000'));
        expect(str, contains('1000000'));
        expect(str, contains('75.0%'));
        expect(str, contains('500'));
      });

      test('returns formatted original size', () {
        final stats = CompressionStats(
          originalSizeBytes: 4194304,
          compressedSizeBytes: 1048576,
          processingTime: const Duration(milliseconds: 500),
        );

        expect(stats.originalSizeFormatted, '4.0 MB');
        expect(stats.compressedSizeFormatted, '1.0 MB');
      });
    });

    group('Compression Scenarios', () {
      test('simulates high compression scenario', () {
        // Large high-resolution photo before compression
        final stats = CompressionStats(
          originalSizeBytes: 8388608, // 8 MB
          compressedSizeBytes: 1048576, // 1 MB
          processingTime: const Duration(milliseconds: 2000),
        );

        expect(stats.compressionRatio, 0.875);
        expect(stats.percentReduction, 87.5);
        expect(stats.originalSizeFormatted, '8.0 MB');
        expect(stats.compressedSizeFormatted, '1.0 MB');
      });

      test('simulates moderate compression scenario', () {
        // Medium phone photo before compression
        final stats = CompressionStats(
          originalSizeBytes: 3145728, // ~3 MB
          compressedSizeBytes: 1048576, // 1 MB
          processingTime: const Duration(milliseconds: 1000),
        );

        expect(stats.percentReduction, closeTo(66.7, 1.0));
        expect(stats.originalSizeFormatted, '3.0 MB');
      });

      test('simulates small image compression', () {
        // Already relatively small image
        final stats = CompressionStats(
          originalSizeBytes: 524288, // 512 KB
          compressedSizeBytes: 393216, // 384 KB
          processingTime: const Duration(milliseconds: 300),
        );

        expect(stats.percentReduction, 25.0);
      });

      test('simulates PNG to JPEG conversion benefit', () {
        // PNG is typically larger than JPEG for photos
        final stats = CompressionStats(
          originalSizeBytes: 5242880, // 5 MB PNG
          compressedSizeBytes: 1572864, // 1.5 MB JPEG
          processingTime: const Duration(milliseconds: 1500),
        );

        expect(stats.percentReduction, closeTo(70.0, 1.0));
      });
    });

    group('Batch Compression Statistics', () {
      test('tracks multiple compressions', () {
        final compressions = [
          CompressionStats(
            originalSizeBytes: 3145728,
            compressedSizeBytes: 1048576,
            processingTime: const Duration(milliseconds: 1000),
          ),
          CompressionStats(
            originalSizeBytes: 4194304,
            compressedSizeBytes: 1310720,
            processingTime: const Duration(milliseconds: 1200),
          ),
          CompressionStats(
            originalSizeBytes: 2097152,
            compressedSizeBytes: 524288,
            processingTime: const Duration(milliseconds: 800),
          ),
        ];

        final totalOriginal =
            compressions.fold<int>(0, (sum, s) => sum + s.originalSizeBytes);
        final totalCompressed =
            compressions.fold<int>(0, (sum, s) => sum + s.compressedSizeBytes);

        expect(totalOriginal, 9437184);
        expect(totalCompressed, 2883584);

        final avgRatio = totalCompressed / totalOriginal;
        expect(avgRatio, closeTo(0.305, 0.01));
      });
    });

    group('Error Scenarios', () {
      test('handles zero file size', () {
        final stats = CompressionStats(
          originalSizeBytes: 0,
          compressedSizeBytes: 0,
          processingTime: const Duration(milliseconds: 0),
        );

        expect(stats.compressionRatio, 0.0);
        expect(stats.percentReduction, 0.0);
        expect(stats.originalSizeFormatted, '0 B');
      });

      test('handles very large file sizes', () {
        final stats = CompressionStats(
          originalSizeBytes: 107374182400, // 100 GB
          compressedSizeBytes: 53687091200, // 50 GB
          processingTime: const Duration(seconds: 30),
        );

        expect(stats.compressionRatio, 0.5);
        expect(stats.percentReduction, 50.0);
        expect(stats.originalSizeFormatted, '100.0 GB');
      });

      test('handles very fast compression', () {
        final stats = CompressionStats(
          originalSizeBytes: 1048576,
          compressedSizeBytes: 524288,
          processingTime: const Duration(milliseconds: 1),
        );

        expect(stats.processingTime.inMilliseconds, 1);
        expect(stats.percentReduction, 50.0);
      });

      test('handles slow compression', () {
        final stats = CompressionStats(
          originalSizeBytes: 10485760,
          compressedSizeBytes: 2621440,
          processingTime: const Duration(seconds: 10),
        );

        expect(stats.processingTime.inSeconds, 10);
        expect(stats.percentReduction, 75.0);
      });
    });
  });
}
