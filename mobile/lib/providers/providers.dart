import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleetopt_ai/models/models.dart';
import 'package:fleetopt_ai/services/api_service.dart';
import 'package:fleetopt_ai/services/offline_service.dart';

// 1. Auth State
class AuthState {
  final AppUser? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.token, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
  String get role => user?.role ?? 'passenger';

  AuthState copyWith({
    AppUser? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await apiService.login(email, password);
      final user = AppUser.fromJson(res['user']);
      final token = res['access_token'] as String;
      state = AuthState(user: user, token: token, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void loginAsDemo(String role) {
    // Quick Demo Switcher
    final demoUsers = {
      'super_admin': AppUser(id: 'u-admin-001', email: 'admin@fleetopt.ai', fullName: 'Alex Mercer (Director)', role: 'super_admin'),
      'driver': AppUser(id: 'u-driver-001', email: 'driver1@fleetopt.ai', fullName: 'Driver #1 (Demo Fleet)', role: 'driver'),
      'depot_manager': AppUser(id: 'u-depot-001', email: 'depot@fleetopt.ai', fullName: 'Marcus Vance (Depot Mgr)', role: 'depot_manager'),
      'passenger': AppUser(id: 'u-passenger-001', email: 'passenger@fleetopt.ai', fullName: 'Sarah Jenkins (Commuter)', role: 'passenger'),
    };
    final user = demoUsers[role] ?? demoUsers['super_admin']!;
    state = AuthState(user: user, token: 'demo-token-$role', isLoading: false);
  }

  void logout() {
    apiService.setAuthToken(null);
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

// 2. Fleet Provider
final vehiclesProvider = FutureProvider<List<VehicleModel>>((ref) async {
  try {
    return await apiService.getVehicles();
  } catch (e) {
    // Default demo fallback if server offline
    return List.generate(10, (i) => VehicleModel(
      id: 'veh-00${i+1}',
      plateNumber: 'BUS-${101+i}',
      status: i == 8 ? 'maintenance' : (i == 9 ? 'breakdown' : 'active'),
      odometerKm: 25000.0 + (i * 3100),
      yearManufactured: 2022,
      qrCode: 'QR-BUS-${101+i}',
    ));
  }
});

final routesProvider = FutureProvider<List<RouteModel>>((ref) async {
  try {
    return await apiService.getRoutes();
  } catch (e) {
    return [
      RouteModel(id: 'r1', routeNumber: 'R101', name: 'Downtown Express', origin: 'Grand Central', destination: 'Wall Street', distanceKm: 12.5, estimatedDurationMinutes: 35),
      RouteModel(id: 'r2', routeNumber: 'R102', name: 'Airport Shuttle', origin: 'Times Square', destination: 'JFK Terminal', distanceKm: 28.0, estimatedDurationMinutes: 55),
      RouteModel(id: 'r3', routeNumber: 'R103', name: 'University Line', origin: 'Columbia Heights', destination: 'Union Square', distanceKm: 14.0, estimatedDurationMinutes: 40),
    ];
  }
});

// 3. Driver Duty Provider with SQLite Offline Cache
final driverDutiesProvider = FutureProvider<List<DriverDutyModel>>((ref) async {
  try {
    final duties = await apiService.getMyDuties();
    if (duties.isNotEmpty) {
      await OfflineService.cacheDuties(duties);
    }
    return duties;
  } catch (e) {
    // Try SQLite offline cache
    final cached = await OfflineService.getCachedDuties();
    if (cached.isNotEmpty) return cached;
    // Fallback default
    return [
      DriverDutyModel(
        id: 'duty-drv-001',
        dutyCode: 'DUTY-NY-MORNING',
        startTime: '08:00',
        endTime: '16:00',
        totalDrivingMinutes: 420,
        status: 'assigned',
        isLocked: true,
        assignedVehicle: 'BUS-101',
        trips: [
          {'trip_number': 'TRIP-R101-01', 'route': 'Downtown Express', 'start_time': '08:00', 'end_time': '08:35'},
          {'trip_number': 'TRIP-R101-02', 'route': 'Downtown Express', 'start_time': '09:00', 'end_time': '09:35'},
          {'trip_number': 'TRIP-R102-01', 'route': 'Airport Shuttle', 'start_time': '11:00', 'end_time': '11:55'},
        ],
        breaks: [
          {'start': '11:55', 'end': '12:40', 'type': 'Mandatory Rest (45m)'}
        ],
      )
    ];
  }
});

// 4. Analytics Provider
final analyticsProvider = FutureProvider<AnalyticsOverviewModel>((ref) async {
  try {
    return await apiService.getAnalytics();
  } catch (e) {
    return AnalyticsOverviewModel(
      activeBuses: 26,
      availableBuses: 30,
      maintenanceBuses: 4,
      driversOnDuty: 35,
      availableDrivers: 37,
      totalTrips: 100,
      coveredTrips: 98,
      uncoveredTrips: 2,
      fleetUtilizationRate: 86.7,
      driverUtilizationRate: 94.6,
      totalOperatingCost: 3350.0,
      breakdownCount: 1,
    );
  }
});

// 5. Route Geometries Provider
final routeGeometriesProvider = FutureProvider<List<RouteGeometryModel>>((ref) async {
  try {
    final routes = await apiService.getRouteGeometries();
    if (routes.isNotEmpty) return routes;
  } catch (e) {
    // Graceful fallback to default geometries
  }
  return [
    RouteGeometryModel(
      id: 'route-r101',
      routeNumber: 'R101',
      name: 'Downtown Express',
      colorHex: '#00A86B',
      waypoints: [
        RouteWaypoint(lat: 40.7527, lng: -73.9772, name: 'Grand Central Terminal'),
        RouteWaypoint(lat: 40.7536, lng: -73.9832, name: 'Bryant Park (42nd St)'),
        RouteWaypoint(lat: 40.7495, lng: -73.9879, name: 'Herald Square (34th St)'),
        RouteWaypoint(lat: 40.7411, lng: -73.9897, name: 'Flatiron District (23rd St)'),
        RouteWaypoint(lat: 40.7359, lng: -73.9911, name: 'Union Square (14th St)'),
        RouteWaypoint(lat: 40.7299, lng: -73.9911, name: 'Astor Place (8th St)'),
        RouteWaypoint(lat: 40.7188, lng: -74.0006, name: 'SoHo Canal Street'),
        RouteWaypoint(lat: 40.7127, lng: -74.0059, name: 'City Hall Broadway'),
        RouteWaypoint(lat: 40.7071, lng: -74.0090, name: 'Wall Street Financial Hub'),
      ],
    ),
    RouteGeometryModel(
      id: 'route-r102',
      routeNumber: 'R102',
      name: 'Airport Shuttle',
      colorHex: '#2A6F97',
      waypoints: [
        RouteWaypoint(lat: 40.7580, lng: -73.9855, name: 'Times Square Terminal'),
        RouteWaypoint(lat: 40.7484, lng: -73.9680, name: 'Midtown East / UN Plaza'),
        RouteWaypoint(lat: 40.7440, lng: -73.9480, name: 'Queens Plaza Link'),
        RouteWaypoint(lat: 40.7380, lng: -73.9100, name: 'Sunnyside Yards'),
        RouteWaypoint(lat: 40.7300, lng: -73.8650, name: 'Rego Park Center'),
        RouteWaypoint(lat: 40.7130, lng: -73.8310, name: 'Kew Gardens Interchange'),
        RouteWaypoint(lat: 40.6850, lng: -73.8050, name: 'Van Wyck South'),
        RouteWaypoint(lat: 40.6440, lng: -73.7820, name: 'JFK Airport Terminal 4'),
      ],
    ),
    RouteGeometryModel(
      id: 'route-r105',
      routeNumber: 'R105',
      name: 'Harbor Promenade',
      colorHex: '#FF9F1C',
      waypoints: [
        RouteWaypoint(lat: 40.7033, lng: -74.0170, name: 'Battery Park Maritime'),
        RouteWaypoint(lat: 40.7126, lng: -74.0134, name: 'World Trade Center West'),
        RouteWaypoint(lat: 40.7190, lng: -74.0115, name: 'Tribeca Waterfront'),
        RouteWaypoint(lat: 40.7330, lng: -74.0090, name: 'West Village Greenway'),
        RouteWaypoint(lat: 40.7460, lng: -74.0080, name: 'Chelsea Piers Sports Complex'),
        RouteWaypoint(lat: 40.7520, lng: -74.0040, name: 'High Line North Park'),
        RouteWaypoint(lat: 40.7540, lng: -74.0020, name: 'Hudson Yards Transit Plaza'),
      ],
    ),
    RouteGeometryModel(
      id: 'route-r106',
      routeNumber: 'R106',
      name: 'Crosstown Link',
      colorHex: '#E63946',
      waypoints: [
        RouteWaypoint(lat: 40.7280, lng: -73.9780, name: 'East Village 1st Ave'),
        RouteWaypoint(lat: 40.7330, lng: -73.9850, name: 'Stuyvesant Square'),
        RouteWaypoint(lat: 40.7360, lng: -73.9910, name: 'Union Square North'),
        RouteWaypoint(lat: 40.7400, lng: -73.9980, name: 'Chelsea 6th Ave'),
        RouteWaypoint(lat: 40.7440, lng: -74.0050, name: 'Meatpacking West'),
      ],
    ),
  ];
});

// 6. Real-Time Vehicle Telemetry Stream (Pulls every 1.5s)
final liveVehicleTelemetryStreamProvider = StreamProvider<List<VehicleLocationModel>>((ref) async* {
  var tick = 0;
  while (true) {
    try {
      final list = await apiService.getVehicleLocations();
      if (list.isNotEmpty) {
        yield list;
      }
    } catch (e) {
      // Local fallback simulation if server unavailable
      tick++;
      final baseProgress = (tick % 100) / 100.0;
      yield List.generate(8, (i) {
        final prog = (baseProgress + (i * 0.12)) % 1.0;
        final lat = 40.7050 + (prog * 0.05);
        final lng = -74.0150 + (prog * 0.04);
        return VehicleLocationModel(
          vehicleId: 'veh-00${i + 1}',
          plateNumber: 'BUS-${101 + i}',
          driverName: 'Driver #${i + 1}',
          routeId: i % 2 == 0 ? 'route-r101' : 'route-r102',
          routeNumber: i % 2 == 0 ? 'R101' : 'R102',
          routeName: i % 2 == 0 ? 'Downtown Express' : 'Airport Shuttle',
          colorHex: i % 2 == 0 ? '#00A86B' : '#2A6F97',
          latitude: lat,
          longitude: lng,
          speedKmh: 32.0 + (i * 2.5),
          heading: (45.0 + i * 40.0) % 360,
          nextStop: 'Stop Station ${i + 1}',
          distanceToNextM: 300 + (i * 45),
          etaMinutes: 1.2,
          occupancyPax: 20 + (i * 3),
          capacity: 55,
          isSimulated: true,
        );
      });
    }
    await Future.delayed(const Duration(milliseconds: 1500));
  }
});

// Legacy backward-compatible provider
final vehicleLocationsProvider = FutureProvider<List<VehicleLocationModel>>((ref) async {
  return ref.watch(liveVehicleTelemetryStreamProvider).value ?? [];
});

// Map View Filter & Selection State
final selectedVehicleIdProvider = StateProvider<String?>((ref) => null);
final selectedRouteFilterProvider = StateProvider<String?>((ref) => null);
final isFollowingVehicleProvider = StateProvider<bool>((ref) => false);
