import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'FleetOpt AI';
  static const String appVersion = '1.0.0+1';
  static const String buildNumber = '1';

  // Environment-injected API Base URL with robust localhost/emulator detection
  static String get apiBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    return 'http://10.0.2.2:8000/api';
  }

  // WebSocket Stream Base URL
  static String get wsBaseUrl {
    const envWs = String.fromEnvironment('WS_BASE_URL');
    if (envWs.isNotEmpty) return envWs;
    if (kIsWeb) return 'ws://127.0.0.1:8000/api';
    return 'ws://10.0.2.2:8000/api';
  }

  // Google Maps Platform API Key (injected via --dart-define=GOOGLE_MAPS_API_KEY=...)
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // GPS & Live Tracking Parameters
  static const int gpsIntervalSeconds = 2;
  static const double distanceFilterMeters = 5.0;
  static const double accuracyThresholdMeters = 25.0;

  // Stale Signal Detection Threshold
  static const Duration staleGpsThreshold = Duration(seconds: 90);

  // Safety & Developer Flags
  static const bool allowSimulatedLocationInDev = bool.fromEnvironment(
    'ALLOW_SIMULATED_LOCATION',
    defaultValue: true,
  );
}
