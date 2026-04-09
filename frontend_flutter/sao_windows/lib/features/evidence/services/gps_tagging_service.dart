// lib/features/evidence/services/gps_tagging_service.dart
// Service for capturing GPS location and tagging evidence with coordinates.
// Used when evidence photos are taken during field operations.

import 'package:geolocator/geolocator.dart';
import '../../../core/utils/logger.dart';

class GpsLocation {
  final double latitude;
  final double longitude;
  final double? accuracy; // meters
  final double? altitude;
  final double? heading;
  final double? speed;
  final int? timestampEpochMs;

  DateTime? get timestamp {
    final value = timestampEpochMs;
    if (value == null || value <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  /// Formatted address (reverse geocoding).
  final String? formattedAddress;

  const GpsLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    this.formattedAddress,
    this.timestampEpochMs,
  });

  /// Distance to another location in meters
  double distanceTo(GpsLocation other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Format as "lat,lng" for metadata
  String toShortString() =>
      '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';

  /// Format with all details
  @override
  String toString() {
    final parts = [
      'Location: $latitude, $longitude',
      if (accuracy != null) 'Accuracy: ${accuracy!.toStringAsFixed(1)}m',
      if (altitude != null) 'Altitude: ${altitude!.toStringAsFixed(1)}m',
      if (heading != null) 'Heading: ${heading!.toStringAsFixed(1)}°',
      if (speed != null) 'Speed: ${(speed! * 3.6).toStringAsFixed(1)} km/h',
    ];
    return parts.join(' | ');
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'altitude': altitude,
        'heading': heading,
        'speed': speed,
      'timestamp': timestamp?.toIso8601String(),
      };

  factory GpsLocation.fromJson(Map<String, dynamic> json) => GpsLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      timestampEpochMs: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String).millisecondsSinceEpoch,
      );
}

class GpsTaggingService {
  /// Request location permissions.
  /// Returns true if permission granted, false if denied.
  static Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.requestPermission();

      switch (permission) {
        case LocationPermission.denied:
          appLogger.w('⚠️ Location permission denied');
          return false;

        case LocationPermission.deniedForever:
          appLogger.w('⚠️ Location permission denied forever - open settings');
          return false;

        case LocationPermission.whileInUse:
        case LocationPermission.always:
          appLogger.i('✅ Location permission granted: $permission');
          return true;

        case LocationPermission.unableToDetermine:
          appLogger.w('⚠️ Unable to determine location permission');
          return false;
      }
    } catch (e, stack) {
      appLogger.e('❌ Error requesting location permission', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Check if location services are enabled.
  static Future<bool> isLocationServiceEnabled() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      appLogger.i(enabled ? '📍 Location services enabled' : '⚠️ Location services disabled');
      return enabled;
    } catch (e, stack) {
      appLogger.e('❌ Error checking location service', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Get current GPS location.
  /// Returns null if location cannot be determined or permission denied.
  static Future<GpsLocation?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // Check permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        appLogger.w('⚠️ Location permission not granted');
        return null;
      }

      // Check service enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        appLogger.w('⚠️ Location services not enabled');
        return null;
      }

      appLogger.i('📍 Fetching current position...');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      final location = GpsLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestampEpochMs: position.timestamp.millisecondsSinceEpoch,
      );

      appLogger.i('✅ Location acquired: $location');
      return location;
    } catch (e, stack) {
      appLogger.e('❌ Error getting current location', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Get location with specified accuracy.
  /// Accuracy options: reduced (city-level), medium (street), high (< 10m)
  static Future<GpsLocation?> getLocationWithAccuracy({
    required LocationAccuracy accuracy,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      appLogger.i('📍 Fetching location with accuracy: $accuracy');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );

      return GpsLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestampEpochMs: position.timestamp.millisecondsSinceEpoch,
      );
    } catch (e, stack) {
      appLogger.e('❌ Error getting location with accuracy $accuracy', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Stream of location updates (for continuous tracking).
  static Stream<GpsLocation> getLocationUpdates({
    int intervalSeconds = 5,
    int distanceFilterMeters = 0,
  }) {
    appLogger.i('📍 Starting location stream (interval: ${intervalSeconds}s, distance: ${distanceFilterMeters}m)');

    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: distanceFilterMeters,
        timeLimit: Duration(seconds: intervalSeconds),
      ),
    ).map((position) {
      return GpsLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestampEpochMs: position.timestamp.millisecondsSinceEpoch,
      );
    }).handleError((Object e, StackTrace stack) {
      appLogger.e('❌ Error in location stream', error: e, stackTrace: stack);
    });
  }

  /// Check if a location is within a specified radius of another location.
  static bool isWithinRadius({
    required GpsLocation subject,
    required GpsLocation centerPoint,
    required double radiusMeters,
  }) {
    final distance = subject.distanceTo(centerPoint);
    const boundaryToleranceMeters = 5.0;
    return distance <= radiusMeters + boundaryToleranceMeters;
  }

  /// Calculate center point of multiple locations (geographic center).
  static GpsLocation? calculateCenterPoint(List<GpsLocation> locations) {
    if (locations.isEmpty) return null;

    double totalLat = 0;
    double totalLng = 0;

    for (final loc in locations) {
      totalLat += loc.latitude;
      totalLng += loc.longitude;
    }

    return GpsLocation(
      latitude: totalLat / locations.length,
      longitude: totalLng / locations.length,
    );
  }
}
