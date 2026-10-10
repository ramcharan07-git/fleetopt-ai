class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String role;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? 'User',
      role: json['role'] ?? 'passenger',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role,
  };
}

class VehicleModel {
  final String id;
  final String plateNumber;
  final String? depotId;
  final String status;
  final double odometerKm;
  final int yearManufactured;
  final String? qrCode;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    this.depotId,
    required this.status,
    required this.odometerKm,
    required this.yearManufactured,
    this.qrCode,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] ?? '',
      plateNumber: json['plate_number'] ?? '',
      depotId: json['depot_id'],
      status: json['status'] ?? 'active',
      odometerKm: (json['odometer_km'] as num?)?.toDouble() ?? 0.0,
      yearManufactured: json['year_manufactured'] ?? 2023,
      qrCode: json['qr_code'],
    );
  }
}

class DriverDutyModel {
  final String id;
  final String dutyCode;
  final String startTime;
  final String endTime;
  final int totalDrivingMinutes;
  final String status;
  final bool isLocked;
  final String assignedVehicle;
  final List<dynamic> trips;
  final List<dynamic> breaks;

  DriverDutyModel({
    required this.id,
    required this.dutyCode,
    required this.startTime,
    required this.endTime,
    required this.totalDrivingMinutes,
    required this.status,
    required this.isLocked,
    required this.assignedVehicle,
    required this.trips,
    required this.breaks,
  });

  factory DriverDutyModel.fromJson(Map<String, dynamic> json) {
    return DriverDutyModel(
      id: json['id'] ?? '',
      dutyCode: json['duty_code'] ?? 'DUTY-01',
      startTime: json['start_time'] ?? '08:00',
      endTime: json['end_time'] ?? '16:00',
      totalDrivingMinutes: json['total_driving_minutes'] ?? 420,
      status: json['status'] ?? 'assigned',
      isLocked: json['is_locked'] ?? false,
      assignedVehicle: json['assigned_vehicle'] ?? 'BUS-101',
      trips: json['trips'] ?? [],
      breaks: json['breaks'] ?? [],
    );
  }
}

class RouteModel {
  final String id;
  final String routeNumber;
  final String name;
  final String origin;
  final String destination;
  final double distanceKm;
  final int estimatedDurationMinutes;

  RouteModel({
    required this.id,
    required this.routeNumber,
    required this.name,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] ?? '',
      routeNumber: json['route_number'] ?? '',
      name: json['name'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 10.0,
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 30,
    );
  }
}

class TripAssignmentModel {
  final String tripId;
  final String tripNumber;
  final String routeNumber;
  final String startTime;
  final String endTime;
  final String? vehiclePlate;
  final String? driverName;
  final bool uncovered;

  TripAssignmentModel({
    required this.tripId,
    required this.tripNumber,
    required this.routeNumber,
    required this.startTime,
    required this.endTime,
    this.vehiclePlate,
    this.driverName,
    required this.uncovered,
  });

  factory TripAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TripAssignmentModel(
      tripId: json['trip_id'] ?? '',
      tripNumber: json['trip_number'] ?? '',
      routeNumber: json['route_number'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      vehiclePlate: json['vehicle_plate'],
      driverName: json['driver_name'],
      uncovered: json['uncovered'] ?? false,
    );
  }
}

class OptimizationResultModel {
  final String scheduleId;
  final String date;
  final String solverStatus;
  final double solveDurationSeconds;
  final double objectiveScore;
  final int totalTrips;
  final int coveredTrips;
  final int uncoveredTrips;
  final int vehiclesUsed;
  final int driversUsed;
  final double estimatedCost;
  final List<TripAssignmentModel> assignments;
  final String? explanation;

  OptimizationResultModel({
    required this.scheduleId,
    required this.date,
    required this.solverStatus,
    required this.solveDurationSeconds,
    required this.objectiveScore,
    required this.totalTrips,
    required this.coveredTrips,
    required this.uncoveredTrips,
    required this.vehiclesUsed,
    required this.driversUsed,
    required this.estimatedCost,
    required this.assignments,
    this.explanation,
  });

  factory OptimizationResultModel.fromJson(Map<String, dynamic> json) {
    final list = (json['assignments'] as List?) ?? [];
    return OptimizationResultModel(
      scheduleId: json['schedule_id'] ?? '',
      date: json['date'] ?? '',
      solverStatus: json['solver_status'] ?? 'FEASIBLE',
      solveDurationSeconds: (json['solve_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      objectiveScore: (json['objective_score'] as num?)?.toDouble() ?? 0.0,
      totalTrips: json['total_trips'] ?? 0,
      coveredTrips: json['covered_trips'] ?? 0,
      uncoveredTrips: json['uncovered_trips'] ?? 0,
      vehiclesUsed: json['vehicles_used'] ?? 0,
      driversUsed: json['drivers_used'] ?? 0,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      assignments: list.map((a) => TripAssignmentModel.fromJson(a)).toList(),
      explanation: json['explanation'],
    );
  }
}

class AnalyticsOverviewModel {
  final int activeBuses;
  final int availableBuses;
  final int maintenanceBuses;
  final int driversOnDuty;
  final int availableDrivers;
  final int totalTrips;
  final int coveredTrips;
  final int uncoveredTrips;
  final double fleetUtilizationRate;
  final double driverUtilizationRate;
  final double totalOperatingCost;
  final int breakdownCount;

  AnalyticsOverviewModel({
    required this.activeBuses,
    required this.availableBuses,
    required this.maintenanceBuses,
    required this.driversOnDuty,
    required this.availableDrivers,
    required this.totalTrips,
    required this.coveredTrips,
    required this.uncoveredTrips,
    required this.fleetUtilizationRate,
    required this.driverUtilizationRate,
    required this.totalOperatingCost,
    required this.breakdownCount,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverviewModel(
      activeBuses: json['active_buses'] ?? 0,
      availableBuses: json['available_buses'] ?? 0,
      maintenanceBuses: json['maintenance_buses'] ?? 0,
      driversOnDuty: json['drivers_on_duty'] ?? 0,
      availableDrivers: json['available_drivers'] ?? 0,
      totalTrips: json['total_trips'] ?? 0,
      coveredTrips: json['covered_trips'] ?? 0,
      uncoveredTrips: json['uncovered_trips'] ?? 0,
      fleetUtilizationRate: (json['fleet_utilization_rate'] as num?)?.toDouble() ?? 0.0,
      driverUtilizationRate: (json['driver_utilization_rate'] as num?)?.toDouble() ?? 0.0,
      totalOperatingCost: (json['total_operating_cost'] as num?)?.toDouble() ?? 0.0,
      breakdownCount: json['breakdown_count'] ?? 0,
    );
  }
}

class VehicleLocationModel {
  final String vehicleId;
  final String plateNumber;
  final String driverName;
  final String routeId;
  final String routeNumber;
  final String routeName;
  final String colorHex;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double heading;
  final String nextStop;
  final int distanceToNextM;
  final double etaMinutes;
  final int occupancyPax;
  final int capacity;
  final String status;
  final String direction;
  final String timestamp;
  final bool isSimulated;

  VehicleLocationModel({
    required this.vehicleId,
    required this.plateNumber,
    this.driverName = 'Driver #1',
    this.routeId = 'route-r101',
    this.routeNumber = 'R101',
    this.routeName = 'Downtown Express',
    this.colorHex = '#00A86B',
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.heading,
    this.nextStop = 'Upcoming Station',
    this.distanceToNextM = 450,
    this.etaMinutes = 1.5,
    this.occupancyPax = 35,
    this.capacity = 55,
    this.status = 'In Transit',
    this.direction = 'Outbound',
    this.timestamp = '',
    required this.isSimulated,
  });

  factory VehicleLocationModel.fromJson(Map<String, dynamic> json) {
    return VehicleLocationModel(
      vehicleId: json['vehicle_id'] ?? '',
      plateNumber: json['plate_number'] ?? 'BUS-101',
      driverName: json['driver_name'] ?? 'Driver #1',
      routeId: json['route_id'] ?? 'route-r101',
      routeNumber: json['route_number'] ?? 'R101',
      routeName: json['route_name'] ?? 'Downtown Express',
      colorHex: json['color_hex'] ?? '#00A86B',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 40.7128,
      longitude: (json['longitude'] as num?)?.toDouble() ?? -74.0060,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 32.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 45.0,
      nextStop: json['next_stop'] ?? 'Next Station',
      distanceToNextM: json['distance_to_next_m'] ?? 500,
      etaMinutes: (json['eta_minutes'] as num?)?.toDouble() ?? 2.0,
      occupancyPax: json['occupancy_pax'] ?? 35,
      capacity: json['capacity'] ?? 55,
      status: json['status'] ?? 'In Transit',
      direction: json['direction'] ?? 'Outbound',
      timestamp: json['timestamp']?.toString() ?? '',
      isSimulated: json['is_simulated'] ?? true,
    );
  }
}

class RouteWaypoint {
  final double lat;
  final double lng;
  final String name;

  RouteWaypoint({required this.lat, required this.lng, required this.name});

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) {
    return RouteWaypoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      name: json['name'] ?? 'Stop',
    );
  }
}

class RouteGeometryModel {
  final String id;
  final String routeNumber;
  final String name;
  final String colorHex;
  final List<RouteWaypoint> waypoints;

  RouteGeometryModel({
    required this.id,
    required this.routeNumber,
    required this.name,
    required this.colorHex,
    required this.waypoints,
  });

  factory RouteGeometryModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['waypoints'] as List?) ?? [];
    return RouteGeometryModel(
      id: json['id'] ?? '',
      routeNumber: json['route_number'] ?? '',
      name: json['name'] ?? '',
      colorHex: json['color'] ?? json['color_hex'] ?? '#00A86B',
      waypoints: rawPoints.map((p) => RouteWaypoint.fromJson(p)).toList(),
    );
  }
}
