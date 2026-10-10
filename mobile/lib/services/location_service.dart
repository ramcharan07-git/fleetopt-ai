import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fleetopt_ai/core/config/app_config.dart';

class LocationReport {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speedKmh;
  final double heading;
  final DateTime timestamp;
  final bool isSimulated;
  final String status;

  LocationReport({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speedKmh,
    required this.heading,
    required this.timestamp,
    required this.isSimulated,
    this.status = 'active',
  });
}

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LocationReport>.broadcast();
  bool _isTracking = false;

  Stream<LocationReport> get locationStream => _locationController.stream;
  bool get isTracking => _isTracking;

  /// Checks and requests runtime GPS permissions.
  Future<bool> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] GPS Location services are disabled on device.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permissions denied by user.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permissions denied forever.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[LocationService] Error verifying permissions: $e');
      return false;
    }
  }

  /// Obtains the driver's single immediate current GPS position.
  Future<LocationReport> getCurrentLocation() async {
    final hasPermission = await checkAndRequestPermission();

    if (hasPermission) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );

        return LocationReport(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          speedKmh: (pos.speed * 3.6).clamp(0.0, 140.0),
          heading: pos.heading,
          timestamp: pos.timestamp,
          isSimulated: pos.isMocked,
          status: 'live_hardware_fix',
        );
      } catch (e) {
        debugPrint('[LocationService] Failed to obtain hardware GPS: $e. Using fallback.');
      }
    }

    // Realistic fallback for emulator / dev environments
    return LocationReport(
      latitude: 40.7527,
      longitude: -73.9772,
      accuracy: 10.0,
      speedKmh: 28.5,
      heading: 90.0,
      timestamp: DateTime.now(),
      isSimulated: true,
      status: 'fallback_simulated_fix',
    );
  }

  /// Starts continuous periodic or distance-based GPS tracking.
  Future<void> startContinuousTracking({
    required Function(LocationReport) onLocation,
  }) async {
    if (_isTracking) return;
    _isTracking = true;

    final hasPermission = await checkAndRequestPermission();

    if (hasPermission) {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (pos) {
          final report = LocationReport(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            speedKmh: (pos.speed * 3.6).clamp(0.0, 140.0),
            heading: pos.heading,
            timestamp: pos.timestamp,
            isSimulated: pos.isMocked,
            status: 'live_stream_fix',
          );
          _locationController.add(report);
          onLocation(report);
        },
        onError: (e) {
          debugPrint('[LocationService] Stream error: $e');
        },
      );
    } else {
      // Fallback timer simulation for emulator or denied permissions
      debugPrint('[LocationService] Running emulator mock kinematic position stream.');
      var tick = 0;
      Timer.periodic(const Duration(seconds: AppConfig.gpsIntervalSeconds), (t) {
        if (!_isTracking) {
          t.cancel();
          return;
        }
        tick++;
        final lat = 40.7527 + (tick * 0.0003);
        final lng = -73.9772 + (tick * 0.0002);
        final report = LocationReport(
          latitude: lat,
          longitude: lng,
          accuracy: 8.0,
          speedKmh: 34.0,
          heading: 45.0,
          timestamp: DateTime.now(),
          isSimulated: true,
          status: 'simulated_tick_fix',
        );
        _locationController.add(report);
        onLocation(report);
      });
    }
  }

  /// Stops GPS collection immediately when tracking ends or duty concludes.
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    debugPrint('[LocationService] GPS location stream stopped.');
  }

  void dispose() {
    stopTracking();
    _locationController.close();
  }
}

final locationService = LocationService();
