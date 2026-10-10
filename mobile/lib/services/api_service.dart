import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fleetopt_ai/config/constants.dart';
import 'package:fleetopt_ai/models/models.dart';

class ApiService {
  late final Dio _dio;
  String? _authToken;
  String _baseUrl = AppConstants.defaultBaseUrl;

  ApiService({String? baseUrl}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        debugPrint('[Dio Error] ${e.requestOptions.uri}: ${e.message}');
        return handler.next(e);
      },
    ));
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  // 1. Authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data;
    if (data['access_token'] != null) {
      setAuthToken(data['access_token']);
    }
    return data;
  }

  // 2. Fleet & Vehicles
  Future<List<VehicleModel>> getVehicles({String? status}) async {
    final response = await _dio.get('/vehicles', queryParameters: {
      if (status != null) 'status': status,
    });
    final list = response.data as List;
    return list.map((json) => VehicleModel.fromJson(json)).toList();
  }

  Future<VehicleModel> updateVehicle(String id, {String? status, double? odometer}) async {
    final response = await _dio.patch('/vehicles/$id', data: {
      if (status != null) 'status': status,
      if (odometer != null) 'odometer_km': odometer,
    });
    return VehicleModel.fromJson(response.data);
  }

  // 3. Transit Routes & Trips
  Future<List<RouteModel>> getRoutes() async {
    final response = await _dio.get('/routes');
    final list = response.data as List;
    return list.map((json) => RouteModel.fromJson(json)).toList();
  }

  // 4. Optimization Engine
  Future<OptimizationResultModel> runOptimization({
    required String date,
    double maxDutyHours = 8.0,
    double minRestHours = 11.0,
  }) async {
    final response = await _dio.post('/optimize', data: {
      'date': date,
      'max_duty_hours': maxDutyHours,
      'min_rest_hours': minRestHours,
    });
    return OptimizationResultModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> approveSchedule(String scheduleId, {String? notes}) async {
    final response = await _dio.post('/schedules/$scheduleId/approve', data: {
      'notes': notes ?? 'Approved by operations manager',
    });
    return response.data;
  }

  Future<Map<String, dynamic>> simulateWhatIf({
    required String date,
    int? availableBuses,
    int absentDrivers = 0,
    double demandPercentage = 100.0,
    int vehicleBreakdowns = 0,
  }) async {
    final response = await _dio.post('/simulate', data: {
      'date': date,
      if (availableBuses != null) 'available_buses_count': availableBuses,
      'absent_drivers_count': absentDrivers,
      'passenger_demand_percentage': demandPercentage,
      'vehicle_breakdowns_count': vehicleBreakdowns,
    });
    return response.data;
  }

  // 5. Driver Duties & Operations
  Future<List<DriverDutyModel>> getMyDuties() async {
    final response = await _dio.get('/drivers/me/duties');
    final list = response.data as List;
    return list.map((json) => DriverDutyModel.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> checkInAttendance({
    required String vehicleId,
    String? qrCodeHash,
  }) async {
    final response = await _dio.post('/attendance/check-in', data: {
      'vehicle_id': vehicleId,
      'qr_code_hash': qrCodeHash,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> reportIncident({
    required String incidentType,
    String? vehicleId,
    required String description,
    String severity = 'medium',
  }) async {
    final response = await _dio.post('/incidents', data: {
      'incident_type': incidentType,
      'vehicle_id': vehicleId,
      'description': description,
      'severity': severity,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> rescheduleDisruption({
    required String incidentId,
    required String scheduleId,
  }) async {
    final response = await _dio.post('/reschedule', data: {
      'incident_id': incidentId,
      'schedule_id': scheduleId,
    });
    return response.data;
  }

  // 6. Analytics & Live Tracking
  Future<AnalyticsOverviewModel> getAnalytics() async {
    final response = await _dio.get('/analytics');
    return AnalyticsOverviewModel.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getDemandPredictions({String? routeId}) async {
    final response = await _dio.get('/demand/predictions', queryParameters: {
      if (routeId != null) 'route_id': routeId,
    });
    return response.data;
  }

  Future<List<VehicleLocationModel>> getVehicleLocations() async {
    final response = await _dio.get('/vehicle-locations');
    final list = response.data as List;
    return list.map((json) => VehicleLocationModel.fromJson(json)).toList();
  }

  Future<List<RouteGeometryModel>> getRouteGeometries() async {
    final response = await _dio.get('/vehicle-locations/routes');
    final list = response.data as List;
    return list.map((json) => RouteGeometryModel.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> reportDeviceGps({
    required String vehicleId,
    required double latitude,
    required double longitude,
    double speedKmh = 0.0,
    double heading = 0.0,
  }) async {
    final response = await _dio.post('/vehicle-locations/report', data: {
      'vehicle_id': vehicleId,
      'latitude': latitude,
      'longitude': longitude,
      'speed_kmh': speedKmh,
      'heading': heading,
    });
    return response.data;
  }

  // 7. Live GPS Tracking Session Management
  Future<Map<String, dynamic>> startTracking({
    required String vehicleId,
    String? tripId,
    String? driverId,
  }) async {
    final response = await _dio.post('/tracking/start', data: {
      'vehicle_id': vehicleId,
      'trip_id': tripId ?? 'trip-r101-01',
      'driver_id': driverId ?? 'drv-001',
    });
    return response.data;
  }

  Future<Map<String, dynamic>> reportTrackingLocation({
    required String vehicleId,
    String? sessionId,
    required double latitude,
    required double longitude,
    double speedKmh = 0.0,
    double heading = 0.0,
    double accuracyMeters = 5.0,
  }) async {
    final response = await _dio.post('/tracking/location', data: {
      'vehicle_id': vehicleId,
      'session_id': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'speed_kmh': speedKmh,
      'heading': heading,
      'accuracy_meters': accuracyMeters,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> stopTracking({
    required String vehicleId,
    String? sessionId,
    String reason = 'trip_completed',
  }) async {
    final response = await _dio.post('/tracking/stop', data: {
      'vehicle_id': vehicleId,
      'session_id': sessionId,
      'reason': reason,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getVehicleLatestLocation(String vehicleId) async {
    final response = await _dio.get('/vehicles/$vehicleId/location');
    return response.data;
  }

  // 8. Turn-by-Turn Road Navigation
  Future<Map<String, dynamic>> getNavigationRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final response = await _dio.get('/navigation/route', queryParameters: {
      'origin_lat': originLat,
      'origin_lng': originLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
    });
    return response.data;
  }

  // 9. Nearest Replacement Bus Proposal
  Future<Map<String, dynamic>> getNearestReplacements({
    String? incidentId,
    String? brokenVehicleId,
  }) async {
    final response = await _dio.get('/replacements/nearest', queryParameters: {
      if (incidentId != null) 'incident_id': incidentId,
      if (brokenVehicleId != null) 'broken_vehicle_id': brokenVehicleId,
    });
    return response.data;
  }

  // 10. Database Health Checks
  Future<Map<String, dynamic>> getMySQLHealth() async {
    final response = await _dio.get('/health/mysql');
    return response.data;
  }

  Future<Map<String, dynamic>> getMongoDBHealth() async {
    final response = await _dio.get('/health/mongodb');
    return response.data;
  }
}

final apiService = ApiService();
