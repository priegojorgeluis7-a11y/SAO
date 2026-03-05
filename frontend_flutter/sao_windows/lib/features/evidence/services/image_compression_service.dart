// lib/features/evidence/services/image_compression_service.dart
// Service for compressing images and videos.
// Reduces file size while maintaining reasonable quality for mobile.

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../../core/utils/logger.dart';

class CompressionStats {
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final Duration processingTime;

  String get originalSizeFormatted => ImageCompressionService.formatFileSize(originalSizeBytes);
  String get compressedSizeFormatted => ImageCompressionService.formatFileSize(compressedSizeBytes);
  double get compressionRatio {
    if (originalSizeBytes <= 0) {
      return 0.0;
    }
    return (originalSizeBytes - compressedSizeBytes) / originalSizeBytes;
  }

  double get percentReduction {
    if (originalSizeBytes <= 0) {
      return 0.0;
    }
    return ((originalSizeBytes - compressedSizeBytes) * 100) / originalSizeBytes;
  }

  CompressionStats({
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.processingTime,
  });

  @override
  String toString() =>
      'Compressed: $originalSizeBytes → $compressedSizeBytes bytes '
      '(${percentReduction.toStringAsFixed(1)}% reduction in ${processingTime.inMilliseconds}ms)';
}

class ImageCompressionService {
  /// Compress JPEG image to reduce file size.
  /// 
  /// Parameters:
  /// - inputPath: Path to original image file
  /// - quality: JPEG quality (1-100, default 75)
  /// - maxWidth: Max width in pixels (default 1920)
  /// - maxHeight: Max height in pixels (default 1920)
  /// 
  /// Returns: Compression stats with new file path
  static Future<CompressionStats> compressImage({
    required String inputPath,
    int quality = 75,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    final startTime = DateTime.now();
    final inputFile = File(inputPath);
    Uint8List originalBytes = Uint8List(0);

    try {
      appLogger.i('🖼️ Starting image compression: $inputPath (quality: $quality)');

      // Read original image
      originalBytes = await inputFile.readAsBytes();
      final originalSize = originalBytes.length;

      // Decode image
      final image = img.decodeImage(originalBytes);
      if (image == null) {
        appLogger.w('⚠️ Could not decode image: $inputPath');
        return CompressionStats(
          originalSizeBytes: originalSize,
          compressedSizeBytes: originalSize,
          processingTime: DateTime.now().difference(startTime),
        );
      }

      // Resize if needed
      img.Image processedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        appLogger.i('📐 Resizing image: ${image.width}x${image.height} → ${maxWidth}x$maxHeight');
        processedImage = img.copyResize(
          image,
          width: maxWidth,
          height: maxHeight,
          interpolation: img.Interpolation.average,
        );
      }

      // Encode as JPEG with specified quality
      final compressedBytes = img.encodeJpg(processedImage, quality: quality);

      // Write compressed image
      final outputPath = inputPath.replaceFirst('.jpg', '_compressed.jpg').replaceFirst('.jpeg', '_compressed.jpg');
      await File(outputPath).writeAsBytes(compressedBytes);

      final duration = DateTime.now().difference(startTime);
      final stats = CompressionStats(
        originalSizeBytes: originalSize,
        compressedSizeBytes: compressedBytes.length,
        processingTime: duration,
      );

      appLogger.i('✅ Image compression complete: $stats');
      return stats;
    } catch (e, stack) {
      appLogger.e('❌ Image compression failed', error: e, stackTrace: stack);
      return CompressionStats(
        originalSizeBytes: originalBytes.length,
        compressedSizeBytes: originalBytes.length,
        processingTime: DateTime.now().difference(startTime),
      );
    }
  }

  /// Compress PNG to JPEG for better compression.
  static Future<CompressionStats> convertPngToJpeg({
    required String inputPath,
    int quality = 80,
  }) async {
    final startTime = DateTime.now();
    final inputFile = File(inputPath);
    Uint8List originalBytes = Uint8List(0);

    try {
      appLogger.i('🖼️ Converting PNG to JPEG: $inputPath');

      originalBytes = await inputFile.readAsBytes();
      final originalSize = originalBytes.length;

      final image = img.decodeImage(originalBytes);
      if (image == null) {
        throw Exception('Could not decode PNG image');
      }

      final jpegBytes = img.encodeJpg(image, quality: quality);

      final outputPath = inputPath.replaceFirst('.png', '.jpg');
      await File(outputPath).writeAsBytes(jpegBytes);

      final stats = CompressionStats(
        originalSizeBytes: originalSize,
        compressedSizeBytes: jpegBytes.length,
        processingTime: DateTime.now().difference(startTime),
      );

      appLogger.i('✅ PNG to JPEG conversion complete: $stats');
      return stats;
    } catch (e, stack) {
      appLogger.e('❌ PNG to JPEG conversion failed', error: e, stackTrace: stack);
      return CompressionStats(
        originalSizeBytes: originalBytes.length,
        compressedSizeBytes: originalBytes.length,
        processingTime: DateTime.now().difference(startTime),
      );
    }
  }

  /// Get human-readable file size string (KB, MB, GB).
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
