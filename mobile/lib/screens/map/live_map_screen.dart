import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/models/models.dart';
import 'package:fleetopt_ai/providers/providers.dart';
import 'package:fleetopt_ai/services/api_service.dart';

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String? _selectedVehicleId;
  String? _selectedRouteNumber; // null means 'All'
  bool _isFollowingBus = false;
  bool _showStops = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      }
    } catch (_) {}
    return AppColors.primaryNavy;
  }

  String _headingToCompass(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = (((heading + 22.5) % 360) / 45).floor();
    return directions[index % 8];
  }

  void _centerOnLocation(double lat, double lng, {double zoom = 14.5}) {
    _mapController.move(LatLng(lat, lng), zoom);
  }

  @override
  Widget build(BuildContext context) {
    final telemetryAsync = ref.watch(liveVehicleTelemetryStreamProvider);
    final geometriesAsync = ref.watch(routeGeometriesProvider);

    final vehicles = telemetryAsync.value ?? [];
    final filteredVehicles = _selectedRouteNumber == null
        ? vehicles
        : vehicles.where((v) => v.routeNumber == _selectedRouteNumber).toList();

    // Find selected vehicle object if any
    final selectedVehicle = vehicles.firstWhere(
      (v) => v.vehicleId == _selectedVehicleId,
      orElse: () => filteredVehicles.isNotEmpty
          ? filteredVehicles.first
          : VehicleLocationModel(
              vehicleId: '',
              plateNumber: '',
              latitude: 40.7128,
              longitude: -74.0060,
              speedKmh: 0,
              heading: 0,
              isSimulated: true,
            ),
    );

    final hasSelection = _selectedVehicleId != null && selectedVehicle.vehicleId.isNotEmpty;

    // Follow bus logic: automatically pan map if tracking enabled
    if (_isFollowingBus && hasSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(selectedVehicle.latitude, selectedVehicle.longitude),
          _mapController.camera.zoom,
        );
      });
    }

    final routes = geometriesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real-Time Live GPS Tracker',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accentTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '1.5s STREAM • ${vehicles.length} ACTIVE BUSES',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    color: AppColors.accentTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hardware GPS Transmitter',
            icon: const Icon(Icons.satellite_alt_rounded),
            onPressed: () => _openHardwareGpsModal(context, vehicles),
          ),
          IconButton(
            tooltip: 'Toggle Transit Stops',
            icon: Icon(
              _showStops ? Icons.pin_drop_rounded : Icons.pin_drop_outlined,
              color: _showStops ? AppColors.accentTeal : Colors.white70,
            ),
            onPressed: () => setState(() => _showStops = !_showStops),
          ),
          IconButton(
            tooltip: 'Reset Hub View',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              setState(() {
                _isFollowingBus = false;
              });
              _centerOnLocation(40.7300, -73.9900, zoom: 13.0);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. High Performance OpenStreetMap Map
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(40.7300, -73.9900),
              initialZoom: 13.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fleetopt.ai',
              ),

              // 2. Route Polylines
              if (routes.isNotEmpty)
                PolylineLayer(
                  polylines: routes.map((route) {
                    final isHighlighted = _selectedRouteNumber == null ||
                        _selectedRouteNumber == route.routeNumber;
                    final routeColor = _hexToColor(route.colorHex);

                    return Polyline(
                      points: route.waypoints
                          .map((wp) => LatLng(wp.lat, wp.lng))
                          .toList(),
                      color: isHighlighted
                          ? routeColor.withOpacity(0.85)
                          : routeColor.withOpacity(0.20),
                      strokeWidth: isHighlighted ? 4.5 : 2.5,
                    );
                  }).toList(),
                ),

              // 3. Transit Stops Layer
              if (_showStops && routes.isNotEmpty)
                MarkerLayer(
                  markers: routes
                      .where((r) =>
                          _selectedRouteNumber == null ||
                          _selectedRouteNumber == r.routeNumber)
                      .expand((route) {
                    final color = _hexToColor(route.colorHex);
                    return route.waypoints.map((wp) {
                      return Marker(
                        point: LatLng(wp.lat, wp.lng),
                        width: 22,
                        height: 22,
                        child: Tooltip(
                          message: '${route.routeNumber}: ${wp.name}',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    });
                  }).toList(),
                ),

              // 4. Live Moving Vehicle Markers with Rotating Heading Arrows
              MarkerLayer(
                markers: filteredVehicles.map((loc) {
                  final isSelected = loc.vehicleId == _selectedVehicleId;
                  final routeColor = _hexToColor(loc.colorHex);
                  final headingRad = (loc.heading * math.pi) / 180.0;

                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedVehicleId = loc.vehicleId;
                        });
                        _centerOnLocation(loc.latitude, loc.longitude);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulsing Ring for Selected Vehicle
                          if (isSelected)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: routeColor,
                                    width: 3.5,
                                  ),
                                  color: routeColor.withOpacity(0.25),
                                ),
                              ),
                            ),

                          // Directional Bus Marker
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? routeColor
                                  : AppColors.primaryNavy,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Rotating Direction Indicator Arrow
                                Transform.rotate(
                                  angle: headingRad,
                                  child: const Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Floating Route Tag
                          Positioned(
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: routeColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                loc.routeNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 5. Top Route Filter Chips Bar
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All Routes (${vehicles.length})',
                    isSelected: _selectedRouteNumber == null,
                    color: AppColors.primaryNavy,
                    onTap: () => setState(() => _selectedRouteNumber = null),
                  ),
                  const SizedBox(width: 8),
                  ...routes.map((r) {
                    final isSel = _selectedRouteNumber == r.routeNumber;
                    final c = _hexToColor(r.colorHex);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: '${r.routeNumber} ${r.name}',
                        isSelected: isSel,
                        color: c,
                        onTap: () {
                          setState(() {
                            _selectedRouteNumber = r.routeNumber;
                          });
                          if (r.waypoints.isNotEmpty) {
                            _centerOnLocation(
                              r.waypoints.first.lat,
                              r.waypoints.first.lng,
                              zoom: 13.5,
                            );
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 6. Interactive Bottom Telemetry Sheet / HUD Card
          if (hasSelection)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildTelemetryHudCard(selectedVehicle),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : color.withOpacity(0.5),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primaryNavy,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryHudCard(VehicleLocationModel loc) {
    final routeColor = _hexToColor(loc.colorHex);
    final compass = _headingToCompass(loc.heading);
    final occupancyPct = (loc.occupancyPax / loc.capacity).clamp(0.0, 1.0);

    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: routeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Vehicle Plate, Route Name, Follow Toggle & Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: routeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    loc.routeNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loc.plateNumber} • ${loc.routeName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${loc.driverName} • ${loc.status}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Follow Bus Toggle
                IconButton(
                  tooltip: _isFollowingBus ? 'Stop Following' : 'Follow Bus Camera',
                  icon: Icon(
                    _isFollowingBus
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                    color: _isFollowingBus ? AppColors.accentTeal : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isFollowingBus = !_isFollowingBus;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedVehicleId = null;
                      _isFollowingBus = false;
                    });
                  },
                ),
              ],
            ),
            const Divider(height: 18),

            // Telemetry Metric Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Speed & Heading
                _buildMetricBlock(
                  icon: Icons.speed_rounded,
                  label: 'SPEED / HEADING',
                  value: '${loc.speedKmh.toStringAsFixed(1)} km/h',
                  sub: '${loc.heading.toStringAsFixed(0)}° $compass',
                  color: AppColors.primaryNavy,
                ),

                // Next Stop & Distance
                _buildMetricBlock(
                  icon: Icons.signpost_rounded,
                  label: 'NEXT STOP',
                  value: loc.nextStop,
                  sub: '${loc.distanceToNextM} m away',
                  color: AppColors.accentTeal,
                  isFlexible: true,
                ),

                // ETA Arrival
                _buildMetricBlock(
                  icon: Icons.timer_outlined,
                  label: 'ARRIVAL ETA',
                  value: '${loc.etaMinutes.toStringAsFixed(1)} min',
                  sub: loc.direction,
                  color: const Color(0xFFD97706),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Passenger Load Capacity Progress Bar
            Row(
              children: [
                const Icon(Icons.groups_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Pax Load: ${loc.occupancyPax} / ${loc.capacity} (${(occupancyPct * 100).toInt()}%)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: loc.isSimulated
                        ? Colors.blue.withOpacity(0.12)
                        : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    loc.isSimulated ? 'KINEMATICS SIM' : 'HARDWARE GPS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: loc.isSimulated ? Colors.blue[800] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: occupancyPct,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  occupancyPct > 0.85
                      ? Colors.red
                      : (occupancyPct > 0.6 ? Colors.orange : Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBlock({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
    bool isFlexible = false,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          sub,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );

    if (isFlexible) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: content,
        ),
      );
    }
    return content;
  }

  // Hardware GPS Ingestion Sheet for Drivers / Field Testers
  void _openHardwareGpsModal(
      BuildContext context, List<VehicleLocationModel> vehicles) {
    String selectedVehId =
        vehicles.isNotEmpty ? vehicles.first.vehicleId : 'veh-001';
    double customLat = 40.7300;
    double customLng = -73.9900;
    double customSpeed = 35.0;
    double customHeading = 90.0;
    bool isBroadcasting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.satellite_alt_rounded,
                          color: AppColors.primaryNavy),
                      const SizedBox(width: 8),
                      const Text(
                        'Hardware GPS Transmitter',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Text(
                    'Simulate physical in-vehicle IoT tracker telemetry or broadcast device GPS directly into the FleetOpt central optimizer.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Select Vehicle
                  DropdownButtonFormField<String>(
                    initialValue: selectedVehId,
                    decoration: const InputDecoration(
                      labelText: 'Select Vehicle to Broadcast',
                      prefixIcon: Icon(Icons.directions_bus),
                    ),
                    items: vehicles.map((v) {
                      return DropdownMenuItem(
                        value: v.vehicleId,
                        child: Text('${v.plateNumber} (${v.routeName})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedVehId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Coordinates Sliders / Preset
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Latitude: ${customLat.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Slider(
                              value: customLat,
                              min: 40.6400,
                              max: 40.7800,
                              onChanged: (v) =>
                                  setModalState(() => customLat = v),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Longitude: ${customLng.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Slider(
                              value: customLng,
                              min: -74.0200,
                              max: -73.7800,
                              onChanged: (v) =>
                                  setModalState(() => customLng = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Speed: ${customSpeed.toStringAsFixed(0)} km/h',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Heading: ${customHeading.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: isBroadcasting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(isBroadcasting
                          ? 'Transmitting GPS Fix...'
                          : 'Transmit Hardware GPS Packet'),
                      onPressed: isBroadcasting
                          ? null
                          : () async {
                              setModalState(() => isBroadcasting = true);
                              try {
                                await apiService.reportDeviceGps(
                                  vehicleId: selectedVehId,
                                  latitude: customLat,
                                  longitude: customLng,
                                  speedKmh: customSpeed,
                                  heading: customHeading,
                                );
                                if (context.mounted) {
                                  Navigator.pop(modalCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Transmitted hardware GPS fix for $selectedVehId!'),
                                      backgroundColor: AppColors.accentTeal,
                                    ),
                                  );
                                  setState(() {
                                    _selectedVehicleId = selectedVehId;
                                  });
                                  _centerOnLocation(customLat, customLng);
                                }
                              } catch (e) {
                                setModalState(() => isBroadcasting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Transmission failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
