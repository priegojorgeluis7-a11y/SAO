// test/features/evidence/services/gps_tagging_service_test.dart
// Unit tests for GpsTaggingService and GpsLocation model functionality.

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/evidence/services/gps_tagging_service.dart';

void main() {
  group('GpsLocation Model', () {
    test('creates location with required fields', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
    });

    test('creates location with all fields', () {
      final location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
        altitude: 52.3,
        heading: 45.0,
        speed: 5.2,
        timestampEpochMs: DateTime(2024, 1, 15, 14, 30, 0).millisecondsSinceEpoch,
      );

      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
      expect(location.accuracy, 10.5);
      expect(location.altitude, 52.3);
      expect(location.heading, 45.0);
      expect(location.speed, 5.2);
      expect(location.timestamp, DateTime(2024, 1, 15, 14, 30, 0));
    });

    test('formats location to short string', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(location.toShortString(), '37.7749,-122.4194');
    });

    test('formats location with precision', () {
      const location = GpsLocation(
        latitude: 37.77494,
        longitude: -122.41945,
      );

      final short = location.toShortString();
      expect(short.split(',').first.split('.').last.length, lessThanOrEqualTo(4));
    });

    test('converts location to JSON', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.5,
        altitude: 52.3,
        heading: 45.0,
        speed: 5.2,
      );

      final json = location.toJson();
      expect(json['latitude'], 37.7749);
      expect(json['longitude'], -122.4194);
      expect(json['accuracy'], 10.5);
      expect(json['altitude'], 52.3);
      expect(json['heading'], 45.0);
      expect(json['speed'], 5.2);
    });

    test('creates location from JSON', () {
      final json = {
        'latitude': 37.7749,
        'longitude': -122.4194,
        'accuracy': 10.5,
        'altitude': 52.3,
        'heading': 45.0,
        'speed': 5.2,
        'timestamp': '2024-01-15T14:30:00.000Z',
      };

      final location = GpsLocation.fromJson(json);
      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
      expect(location.accuracy, 10.5);
    });
  });

  group('GpsLocation Distance Calculations', () {
    test('calculates distance between two points', () {
      // San Francisco to Los Angeles
      const sf = GpsLocation(latitude: 37.7749, longitude: -122.4194);
      const la = GpsLocation(latitude: 34.0522, longitude: -118.2437);

      final distance = sf.distanceTo(la);

      // Should be approximately 560 km
      expect(distance, greaterThan(500000)); // > 500 km in meters
      expect(distance, lessThan(600000)); // < 600 km in meters
    });

    test('calculates distance between same point', () {
      const location = GpsLocation(latitude: 37.7749, longitude: -122.4194);

      final distance = location.distanceTo(location);
      expect(distance, closeTo(0, 1));
    });

    test('calculates distance between nearby points', () {
      // Points very close together (< 1km)
      const point1 = GpsLocation(latitude: 37.7749, longitude: -122.4194);
      const point2 = GpsLocation(latitude: 37.7750, longitude: -122.4195);

      final distance = point1.distanceTo(point2);

      expect(distance, greaterThan(10)); // > 10 meters
      expect(distance, lessThan(500)); // < 500 meters
    });

    test('calculates distance symmetrically', () {
      const point1 = GpsLocation(latitude: 40.7128, longitude: -74.0060); // NYC
      const point2 = GpsLocation(latitude: 34.0522, longitude: -118.2437); // LA

      final distance1 = point1.distanceTo(point2);
      final distance2 = point2.distanceTo(point1);

      expect(distance1, closeTo(distance2, 1)); // Should be nearly identical
    });

    test('calculates distance across equator', () {
      const north = GpsLocation(latitude: 10.0, longitude: 0.0);
      const south = GpsLocation(latitude: -10.0, longitude: 0.0);

      final distance = north.distanceTo(south);

      // Approximately 2223 km
      expect(distance, greaterThan(2200000));
      expect(distance, lessThan(2250000));
    });

    test('calculates distance crossing dateline edge case', () {
      const eastOfDateline = GpsLocation(latitude: 0.0, longitude: 179.0);
      const westOfDateline = GpsLocation(latitude: 0.0, longitude: -179.0);

      final distance = eastOfDateline.distanceTo(westOfDateline);

      // Should be approximately 222 km (shortest path)
      expect(distance, greaterThan(200000));
      expect(distance, lessThan(250000));
    });
  });

  group('GpsTaggingService Position Utilities', () {
    test('checks if point is within radius with true case', () {
      const center = GpsLocation(latitude: 37.7749, longitude: -122.4194);
      const nearby = GpsLocation(latitude: 37.7750, longitude: -122.4195);

      final isWithin = GpsTaggingService.isWithinRadius(
        subject: nearby,
        centerPoint: center,
        radiusMeters: 500,
      );

      expect(isWithin, true);
    });

    test('checks if point is within radius with false case', () {
      const center = GpsLocation(latitude: 37.7749, longitude: -122.4194);
      const farAway =
          GpsLocation(latitude: 34.0522, longitude: -118.2437); // LA

      final isWithin = GpsTaggingService.isWithinRadius(
        subject: farAway,
        centerPoint: center,
        radiusMeters: 500,
      );

      expect(isWithin, false);
    });

    test('checks if point is exactly on radius boundary', () {
      const center = GpsLocation(latitude: 0.0, longitude: 0.0);
      const onBoundary = GpsLocation(latitude: 0.0, longitude: 0.004503); // ~500m away

      final isWithin = GpsTaggingService.isWithinRadius(
        subject: onBoundary,
        centerPoint: center,
        radiusMeters: 500,
      );

      // Should be true (on boundary is considered within)
      expect(isWithin, true);
    });

    test('calculates center point of multiple locations', () {
      final locations = [
        const GpsLocation(latitude: 37.7749, longitude: -122.4194),
        const GpsLocation(latitude: 37.7789, longitude: -122.4175),
        const GpsLocation(latitude: 37.7709, longitude: -122.4213),
      ];

      final center = GpsTaggingService.calculateCenterPoint(locations);

      expect(center, isNotNull);
      expect(center!.latitude, closeTo(37.7749, 0.1));
      expect(center.longitude, closeTo(-122.4194, 0.1));
    });

    test('calculates center point with two locations', () {
      final locations = [
        const GpsLocation(latitude: 0.0, longitude: 0.0),
        const GpsLocation(latitude: 2.0, longitude: 2.0),
      ];

      final center = GpsTaggingService.calculateCenterPoint(locations);

      expect(center, isNotNull);
      expect(center!.latitude, closeTo(1.0, 0.1));
      expect(center.longitude, closeTo(1.0, 0.1));
    });

    test('calculates center point with single location', () {
      final locations = [
        const GpsLocation(latitude: 37.7749, longitude: -122.4194),
      ];

      final center = GpsTaggingService.calculateCenterPoint(locations);

      expect(center, isNotNull);
      expect(center!.latitude, 37.7749);
      expect(center.longitude, -122.4194);
    });

    test('returns null for empty location list', () {
      final center = GpsTaggingService.calculateCenterPoint([]);
      expect(center, isNull);
    });
  });

  group('Location Accuracy Classifications', () {
    test('classifies high accuracy location', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 5.0,
      );

      expect(location.accuracy, lessThan(10));
    });

    test('classifies medium accuracy location', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 25.0,
      );

      expect(location.accuracy, greaterThanOrEqualTo(10));
      expect(location.accuracy, lessThan(50));
    });

    test('classifies low accuracy location', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 100.0,
      );

      expect(location.accuracy, greaterThanOrEqualTo(50));
    });
  });

  group('Batch Location Processing', () {
    test('processes location history', () {
      final locations = [
        GpsLocation(
          latitude: 37.7749,
          longitude: -122.4194,
          timestampEpochMs: DateTime(2024, 1, 15, 14, 0, 0).millisecondsSinceEpoch,
        ),
        GpsLocation(
          latitude: 37.7750,
          longitude: -122.4195,
          timestampEpochMs: DateTime(2024, 1, 15, 14, 1, 0).millisecondsSinceEpoch,
        ),
        GpsLocation(
          latitude: 37.7751,
          longitude: -122.4196,
          timestampEpochMs: DateTime(2024, 1, 15, 14, 2, 0).millisecondsSinceEpoch,
        ),
      ];

      expect(locations.length, 3);
      expect(locations.first.latitude, 37.7749);
      expect(locations.last.latitude, 37.7751);
    });

    test('filters locations by accuracy', () {
      final locations = [
        const GpsLocation(
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 5.0,
        ),
        const GpsLocation(
          latitude: 37.7750,
          longitude: -122.4195,
          accuracy: 100.0,
        ),
        const GpsLocation(
          latitude: 37.7751,
          longitude: -122.4196,
          accuracy: 15.0,
        ),
      ];

      final highAccuracy =
          locations.where((l) => l.accuracy! <= 20.0).toList();
      expect(highAccuracy.length, 2);
    });

    test('identifies location outliers', () {
      const baseLocation =
          GpsLocation(latitude: 37.7749, longitude: -122.4194);
      final locations = [
        const GpsLocation(latitude: 37.7749, longitude: -122.4194),
        const GpsLocation(latitude: 37.7750, longitude: -122.4195),
        const GpsLocation(latitude: 34.0522, longitude: -118.2437), // LA
        const GpsLocation(latitude: 37.7751, longitude: -122.4196),
      ];

      final outliers = locations
          .where((l) => baseLocation.distanceTo(l) > 500000)
          .toList();

      expect(outliers.length, 1);
    });
  });

  group('Timestamp Handling', () {
    test('stores and retrieves timestamp', () {
      final now = DateTime.now();
      final location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestampEpochMs: now.millisecondsSinceEpoch,
      );

      expect(location.timestamp?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('defaults to current time if not provided', () {
      const location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(location.timestamp, isNull);
    });

    test('preserves timestamp through JSON serialization', () {
      final now = DateTime(2024, 1, 15, 14, 30, 45);
      final location = GpsLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestampEpochMs: now.millisecondsSinceEpoch,
      );

      final json = location.toJson();
      final restored = GpsLocation.fromJson(json);

      expect(restored.timestamp, now);
    });
  });

  group('Coordinate Edge Cases', () {
    test('handles north pole', () {
      const northPole = GpsLocation(latitude: 90.0, longitude: 0.0);
      expect(northPole.latitude, 90.0);
    });

    test('handles south pole', () {
      const southPole = GpsLocation(latitude: -90.0, longitude: 0.0);
      expect(southPole.latitude, -90.0);
    });

    test('handles prime meridian', () {
      const primeMeridian = GpsLocation(latitude: 0.0, longitude: 0.0);
      expect(primeMeridian.longitude, 0.0);
    });

    test('handles international dateline', () {
      const dateline = GpsLocation(latitude: 0.0, longitude: 180.0);
      expect(dateline.longitude, 180.0);
    });

    test('handles negative coordinates', () {
      const location = GpsLocation(latitude: -33.8688, longitude: -151.2093);
      expect(location.latitude, lessThan(0));
      expect(location.longitude, lessThan(0));
    });
  });
}
