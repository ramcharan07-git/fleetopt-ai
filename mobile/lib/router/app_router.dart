import 'package:go_router/go_router.dart';
import 'package:fleetopt_ai/screens/auth/login_screen.dart';
import 'package:fleetopt_ai/screens/admin/admin_dashboard.dart';
import 'package:fleetopt_ai/screens/admin/optimization_screen.dart';
import 'package:fleetopt_ai/screens/admin/simulator_screen.dart';
import 'package:fleetopt_ai/screens/admin/fleet_screen.dart';
import 'package:fleetopt_ai/screens/admin/analytics_screen.dart';
import 'package:fleetopt_ai/screens/driver/driver_dashboard.dart';
import 'package:fleetopt_ai/screens/driver/qr_checkin_screen.dart';
import 'package:fleetopt_ai/screens/driver/incident_report_screen.dart';
import 'package:fleetopt_ai/screens/driver/duty_swap_screen.dart';
import 'package:fleetopt_ai/screens/depot/depot_dashboard.dart';
import 'package:fleetopt_ai/screens/passenger/passenger_dashboard.dart';
import 'package:fleetopt_ai/screens/map/live_map_screen.dart';
import 'package:fleetopt_ai/screens/navigation/driver_navigation_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Admin Routes
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
      routes: [
        GoRoute(
          path: 'optimize',
          builder: (context, state) => const OptimizationScreen(),
        ),
        GoRoute(
          path: 'simulate',
          builder: (context, state) => const SimulatorScreen(),
        ),
        GoRoute(
          path: 'fleet',
          builder: (context, state) => const FleetScreen(),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
      ],
    ),
    // Driver Routes
    GoRoute(
      path: '/driver',
      builder: (context, state) => const DriverDashboardScreen(),
      routes: [
        GoRoute(
          path: 'checkin',
          builder: (context, state) => const QrCheckinScreen(),
        ),
        GoRoute(
          path: 'incident',
          builder: (context, state) => const IncidentReportScreen(),
        ),
        GoRoute(
          path: 'swap',
          builder: (context, state) => const DutySwapScreen(),
        ),
        GoRoute(
          path: 'navigation',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return DriverNavigationScreen(
              vehicleId: extra?['vehicle_id'] ?? 'veh-001',
              routeNumber: extra?['route_number'] ?? 'R101',
              routeName: extra?['route_name'] ?? 'Downtown Express',
              destinationLat: (extra?['destination_lat'] as num?)?.toDouble() ?? 40.7071,
              destinationLng: (extra?['destination_lng'] as num?)?.toDouble() ?? -74.0090,
            );
          },
        ),
      ],
    ),
    // Depot Manager Route
    GoRoute(
      path: '/depot',
      builder: (context, state) => const DepotDashboardScreen(),
    ),
    // Passenger Route
    GoRoute(
      path: '/passenger',
      builder: (context, state) => const PassengerDashboardScreen(),
    ),
    // Live Map
    GoRoute(
      path: '/map',
      builder: (context, state) => const LiveMapScreen(),
    ),
    // Direct Navigation Route
    GoRoute(
      path: '/navigation',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return DriverNavigationScreen(
          vehicleId: extra?['vehicle_id'] ?? 'veh-001',
          routeNumber: extra?['route_number'] ?? 'R101',
          routeName: extra?['route_name'] ?? 'Downtown Express',
          destinationLat: (extra?['destination_lat'] as num?)?.toDouble() ?? 40.7071,
          destinationLng: (extra?['destination_lng'] as num?)?.toDouble() ?? -74.0090,
        );
      },
    ),
  ],
);
