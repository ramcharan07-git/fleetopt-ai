import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/services/api_service.dart';
import 'package:fleetopt_ai/services/location_service.dart';
import 'package:fleetopt_ai/services/navigation_service.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
  final String vehicleId;
  final String routeNumber;
  final String routeName;
  final double destinationLat;
  final double destinationLng;

  const DriverNavigationScreen({
    super.key,
    this.vehicleId = 'veh-001',
    this.routeNumber = 'R101',
    this.routeName = 'Downtown Express',
    this.destinationLat = 40.7071,
    this.destinationLng = -74.0090,
  });

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends ConsumerState<DriverNavigationScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<LocationReport>? _locationSub;

  LocationReport? _currentLocation;
  NavigationRouteData? _routeData;
  String? _activeSessionId;

  bool _isNavigating = false;
  bool _isLoadingRoute = true;
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    if (_isNavigating && _activeSessionId != null) {
      apiService.stopTracking(
        vehicleId: widget.vehicleId,
        sessionId: _activeSessionId,
      );
    }
    locationService.stopTracking();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    // 1. Obtain current GPS position
    final initialPos = await locationService.getCurrentLocation();
    setState(() {
      _currentLocation = initialPos;
    });

    // 2. Fetch genuine road directions from backend
    final directions = await navigationService.getRouteDirections(
      originLat: initialPos.latitude,
      originLng: initialPos.longitude,
      destLat: widget.destinationLat,
      destLng: widget.destinationLng,
    );

    setState(() {
      _routeData = directions;
      _isLoadingRoute = false;
    });

    // 3. Start live tracking session
    try {
      final sess = await apiService.startTracking(
        vehicleId: widget.vehicleId,
        tripId: 'trip-${widget.routeNumber.toLowerCase()}-01',
        driverId: 'drv-001',
      );
      _activeSessionId = sess['session_id'];
    } catch (e) {
      debugPrint('[Navigation] Start tracking session offline: $e');
    }

    // 4. Listen to continuous GPS stream
    _isNavigating = true;
    _locationSub = locationService.locationStream.listen((loc) {
      setState(() {
        _currentLocation = loc;
      });

      // Transmit to central fleet engine
      apiService.reportTrackingLocation(
        vehicleId: widget.vehicleId,
        sessionId: _activeSessionId,
        latitude: loc.latitude,
        longitude: loc.longitude,
        speedKmh: loc.speedKmh,
        heading: loc.heading,
        accuracyMeters: loc.accuracy,
      );

      // Auto-center map on vehicle
      _mapController.move(
        LatLng(loc.latitude, loc.longitude),
        _mapController.camera.zoom,
      );
    });

    // Start hardware/mock continuous tracking
    locationService.startContinuousTracking(onLocation: (l) {});
  }

  IconData _getManeuverIcon(String maneuverType, String modifier) {
    if (maneuverType == 'arrive') return Icons.flag_rounded;
    if (modifier.contains('left')) return Icons.turn_left_rounded;
    if (modifier.contains('right')) return Icons.turn_right_rounded;
    if (modifier.contains('slight')) return Icons.fork_right_rounded;
    return Icons.straight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final currentPos = _currentLocation != null
        ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
        : const LatLng(40.7527, -73.9772);

    final destPos = LatLng(widget.destinationLat, widget.destinationLng);
    final polylinePoints = _routeData?.polylineCoordinates ?? [currentPos, destPos];
    final steps = _routeData?.steps ?? [];
    final currentStep = steps.isNotEmpty
        ? steps[_currentStepIndex.clamp(0, steps.length - 1)]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.routeNumber} Navigation',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              '${widget.routeName} • ${widget.vehicleId.toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Launch External Google Maps',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () {
              navigationService.launchExternalMapsApp(
                widget.destinationLat,
                widget.destinationLng,
              );
            },
          ),
          IconButton(
            tooltip: 'Center on GPS',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(
                  LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
                  15.5,
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. High Performance Leaflet OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentPos,
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fleetopt.ai',
              ),

              // Road Polyline Layer
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    color: AppColors.accentBlue,
                    strokeWidth: 5.5,
                  ),
                ],
              ),

              // Destination & Stops Marker Layer
              MarkerLayer(
                markers: [
                  // Destination Flag
                  Marker(
                    point: destPos,
                    width: 38,
                    height: 38,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.criticalRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
                    ),
                  ),

                  // Current Driver GPS Location Marker
                  Marker(
                    point: currentPos,
                    width: 50,
                    height: 50,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.operationalGreen.withValues(alpha: 0.25),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.operationalGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 6),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: ((_currentLocation?.heading ?? 0.0) * 3.14159) / 180.0,
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Turn-by-Turn Maneuver Instruction Banner
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 8,
              color: AppColors.primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.operationalTeal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        currentStep != null
                            ? _getManeuverIcon(currentStep.maneuverType, currentStep.maneuverModifier)
                            : Icons.straight_rounded,
                        color: AppColors.operationalTeal,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStep?.instruction ?? 'Proceed along designated route',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Next Turn in ${currentStep?.distanceMeters ?? 250} m',
                            style: const TextStyle(
                              color: AppColors.operationalTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Loading Indicator
          if (_isLoadingRoute)
            const Positioned(
              top: 90,
              left: 20,
              right: 20,
              child: LinearProgressIndicator(),
            ),

          // 4. Bottom Navigation Telemetry & Trip Controls HUD
          Positioned(
            bottom: 16,
            left: 14,
            right: 14,
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stats Row: Distance, ETA, Speed
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBlock(
                          icon: Icons.alt_route_rounded,
                          label: 'DISTANCE',
                          value: '${_routeData?.totalDistanceKm.toStringAsFixed(1) ?? "--"} km',
                        ),
                        _buildStatBlock(
                          icon: Icons.timer_outlined,
                          label: 'ETA ARRIVAL',
                          value: '${_routeData?.estimatedDurationMinutes.toStringAsFixed(0) ?? "--"} min',
                          color: AppColors.warningOrange,
                        ),
                        _buildStatBlock(
                          icon: Icons.speed_rounded,
                          label: 'SPEED',
                          value: '${_currentLocation?.speedKmh.toStringAsFixed(0) ?? "0"} km/h',
                          color: AppColors.operationalGreen,
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Action Buttons Row
                    Row(
                      children: [
                        // Report Delay / Incident
                        OutlinedButton.icon(
                          icon: const Icon(Icons.warning_amber_rounded, size: 18),
                          label: const Text('Report Delay', style: TextStyle(fontSize: 12)),
                          onPressed: () => context.push('/incident-report'),
                        ),
                        const SizedBox(width: 8),

                        // End Navigation & Complete Trip
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.criticalRed,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('End Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Complete Assigned Trip?'),
                                  content: const Text(
                                    'This will end the active GPS tracking session and record completion in MySQL and MongoDB.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Complete Trip'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                await apiService.stopTracking(
                                  vehicleId: widget.vehicleId,
                                  sessionId: _activeSessionId,
                                  reason: 'driver_trip_completed',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Trip completed & tracking session finalized.'),
                                      backgroundColor: AppColors.operationalGreen,
                                    ),
                                  );
                                  context.pop();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock({
    required IconData icon,
    required String label,
    required String value,
    Color color = AppColors.primaryNavy,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.lightTextSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
