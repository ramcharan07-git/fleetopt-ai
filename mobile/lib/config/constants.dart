import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'FleetOpt AI';
  static const String appTagline = 'Autonomous Fleet & Driver Optimizer';
  
  // Dynamic API URL: 127.0.0.1 on Web / Desktop, 10.0.2.2 on Android Emulator
  static String get defaultBaseUrl => kIsWeb ? 'http://127.0.0.1:8000/api' : 'http://10.0.2.2:8000/api';
  static const String localHostUrl = 'http://127.0.0.1:8000/api';
  static const String lanBaseUrl = 'http://localhost:8000/api';

  // Storage Keys
  static const String tokenKey = 'fleetopt_access_token';
  static const String userKey = 'fleetopt_user_data';
  static const String cachedDutiesKey = 'fleetopt_cached_duties';
  static const String lastSyncKey = 'fleetopt_last_sync_timestamp';

  // Roles
  static const String roleAdmin = 'super_admin';
  static const String roleDriver = 'driver';
  static const String roleDepotManager = 'depot_manager';
  static const String rolePassenger = 'passenger';
}
