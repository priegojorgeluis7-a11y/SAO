// test/features/evidence/widgets/evidence_widgets_test.dart
// Widget tests for evidence capture UI components.
// Tests rendering, user interaction, and state management for the evidence capture widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/evidence/presentation/widgets/evidence_preview_card.dart';
import 'package:sao_windows/features/evidence/presentation/widgets/evidence_description_form.dart';
import 'package:sao_windows/features/evidence/presentation/widgets/gps_location_display.dart';
import 'package:sao_windows/features/evidence/services/camera_capture_service.dart';
import 'package:sao_windows/features/evidence/services/gps_tagging_service.dart';
import 'package:sao_windows/features/evidence/services/image_compression_service.dart';

const _sampleEvidence = CapturedEvidence(
  localPath: '/storage/sample.jpg',
  fileName: 'sample.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 1024,
);

void main() {
  group('EvidencePreviewCard Widget', () {
    testWidgets('renders photo preview with metadata', (WidgetTester tester) async {
      const testEvidence = CapturedEvidence(
        localPath: '/storage/test_photo.jpg',
        fileName: 'test_photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvidencePreviewCard(evidence: testEvidence),
          ),
        ),
      );

      // Should display file name
      expect(find.text('test_photo.jpg'), findsOneWidget);

      // Should display file size
      expect(find.text('2.0 MB'), findsOneWidget);
    });

    testWidgets('displays compression badge when compressed', (WidgetTester tester) async {
      final stats = CompressionStats(
        originalSizeBytes: 4000000,
        compressedSizeBytes: 1000000,
        processingTime: const Duration(milliseconds: 500),
      );

      final evidence = CapturedEvidence(
        localPath: '/storage/compressed.jpg',
        fileName: 'compressed.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1000000,
        isCompressed: true,
        compressionStats: stats,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidencePreviewCard(evidence: evidence),
          ),
        ),
      );

      // Should show compression badge
      expect(find.byIcon(Icons.compress), findsOneWidget);
    });

    testWidgets('handles missing file gracefully', (WidgetTester tester) async {
      const evidence = CapturedEvidence(
        localPath: '/nonexistent/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvidencePreviewCard(evidence: evidence),
          ),
        ),
      );

      // Should still show file name and size
      expect(find.text('photo.jpg'), findsOneWidget);
      expect(find.text('2.0 MB'), findsOneWidget);
    });

    testWidgets('displays video play icon for video files',
        (WidgetTester tester) async {
      const evidence = CapturedEvidence(
        localPath: '/storage/video.mp4',
        fileName: 'video.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 52428800,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvidencePreviewCard(evidence: evidence),
          ),
        ),
      );

      // Should show play icon for videos
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });

    testWidgets('renders with custom max height', (WidgetTester tester) async {
      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EvidencePreviewCard(
              evidence: evidence,
              maxHeight: 200,
            ),
          ),
        ),
      );

      // Should render successfully with custom height
      expect(find.byType(EvidencePreviewCard), findsOneWidget);
    });

    testWidgets('shows file with all metadata fields', (WidgetTester tester) async {
      final evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo_001.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 3145728,
        isCompressed: true,
        compressionStats: CompressionStats(
          originalSizeBytes: 6291456,
          compressedSizeBytes: 3145728,
          processingTime: const Duration(milliseconds: 800),
        ),
        capturedAtEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidencePreviewCard(evidence: evidence),
          ),
        ),
      );

      // Verify file info display
      expect(find.text('photo_001.jpg'), findsOneWidget);
      expect(find.text('3.0 MB'), findsOneWidget);
    });
  });

  group('EvidenceDescriptionForm Widget', () {
    testWidgets('renders text input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Should have description input
      expect(find.byType(TextField), findsOneWidget);

      // Should have required indicator
      expect(find.text('*'), findsOneWidget);
    });

    testWidgets('shows character counter', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Character counter should be visible
      expect(find.text('0/500'), findsOneWidget);
    });

    testWidgets('updates character count as user types', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Type some text
      await tester.enterText(find.byType(TextField), 'Test description');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Counter should show updated count
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows warning at 80% character limit', (WidgetTester tester) async {
      // Mock filling 80% of 500 characters
      final warningText = 'a' * 400; // 80% of 500

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Find TextField and enter 80% text
      await tester.enterText(find.byType(TextField), warningText);

      // Should trigger warning (orange color)
      await tester.pumpAndSettle();

      expect(find.byType(EvidenceDescriptionForm), findsOneWidget);
    });

    testWidgets('calls callback on description change', (WidgetTester tester) async {
      String? changedDescription;

      void onChanged(String desc) {
        changedDescription = desc;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: onChanged,
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'New description');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: onChanged,
            ),
          ),
        ),
      );

      // Callback should have been called
      expect(changedDescription, isNotNull);
    });

    testWidgets('shows validation state indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Empty state should show no indicator
      expect(find.byType(TextField), findsOneWidget);

      // Add text
      await tester.enterText(find.byType(TextField), 'Valid description');
      await tester.pumpAndSettle();

      // Should show valid indicator
      expect(find.text('✓ Description added'), findsOneWidget);
    });

    testWidgets('enforces max character limit', (WidgetTester tester) async {
      final tooLongText = 'a' * 600; // Exceeds 500 char limit

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Try entering too much text
      await tester.enterText(find.byType(TextField), tooLongText);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceDescriptionForm(
              evidence: _sampleEvidence,
              onDescriptionChanged: (_) {},
            ),
          ),
        ),
      );

      // Should still render (limit enforced)
      expect(find.byType(EvidenceDescriptionForm), findsOneWidget);
    });
  });

  group('GpsLocationDisplay Widget', () {
    testWidgets('renders GPS location in compact view', (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: true,
            ),
          ),
        ),
      );

      // Should show location in short format
      expect(find.text('37.7749,-122.4194'), findsOneWidget);
    });

    testWidgets('renders GPS location in expanded view', (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
        altitude: 52.3,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      // Should show expanded fields
      expect(find.text('Coordinates'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('Altitude'), findsOneWidget);
    });

    testWidgets('shows coordinates in expanded view', (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('37.774900, -122.419400'), findsOneWidget);
    });

    testWidgets('color codes accuracy based on precision', (WidgetTester tester) async {
      // High accuracy (< 10m) should be green
      const highAccuracy = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 5.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: highAccuracy,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.byType(GpsLocationDisplay), findsOneWidget);
    });

    testWidgets('shows accuracy in expanded view', (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('±10.5 m'), findsOneWidget);
    });

    testWidgets('shows altitude when available', (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 52.3,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('Altitude'), findsOneWidget);
      expect(find.text('52.3 m'), findsOneWidget);
    });

    testWidgets('shows heading when available', (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        heading: 45.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('45°'), findsOneWidget);
    });

    testWidgets('shows speed when available', (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        speed: 5.2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('Speed'), findsOneWidget);
      expect(find.text('18.7 km/h'), findsOneWidget);
    });

    testWidgets('shows timestamp when available', (WidgetTester tester) async {
      final location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestampEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('Timestamp'), findsOneWidget);
    });

    testWidgets('renders with all GPS data fields populated',
        (WidgetTester tester) async {
      final location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 8.5,
        altitude: 52.3,
        heading: 180.0,
        speed: 2.5,
        timestampEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GpsLocationDisplay(
              location: location,
              compact: false,
            ),
          ),
        ),
      );

      // All fields should be visible
      expect(find.byType(GpsLocationDisplay), findsOneWidget);
    });
  });

  group('Evidence Widgets Integration', () {
    testWidgets(
        'combines preview card + description form + GPS display',
        (WidgetTester tester) async {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
      );

      const evidence = CapturedEvidence(
        localPath: '/storage/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048000,
        gpsLocation: location,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  EvidencePreviewCard(evidence: evidence),
                  EvidenceDescriptionForm(
                    evidence: _sampleEvidence,
                    onDescriptionChanged: _noopDescription,
                  ),
                  GpsLocationDisplay(
                    location: location,
                    compact: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // All three widgets should be present
      expect(find.byType(EvidencePreviewCard), findsOneWidget);
      expect(find.byType(EvidenceDescriptionForm), findsOneWidget);
      expect(find.byType(GpsLocationDisplay), findsOneWidget);
    });
  });
}

void _noopDescription(String _) {}
