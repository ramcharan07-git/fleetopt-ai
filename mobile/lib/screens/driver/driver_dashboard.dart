import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/providers/providers.dart';
import 'package:fleetopt_ai/widgets/app_drawer.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dutiesAsync = ref.watch(driverDutiesProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Portal • My Duty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'QR Duty Check-In',
            onPressed: () => context.go('/driver/checkin'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(driverDutiesProvider),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(driverDutiesProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Driver Header Card
              Card(
                color: AppColors.primaryNavy,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.person, size: 32, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Driver #1',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Certified Bus Operator • Central Depot',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: const [
                                Icon(Icons.cloud_done, color: AppColors.operationalTeal, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Synchronized with MySQL & MongoDB',
                                  style: TextStyle(fontSize: 11, color: AppColors.operationalTeal, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Duty Card
              dutiesAsync.when(
                data: (duties) {
                  if (duties.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No duties assigned for today.')),
                      ),
                    );
                  }
                  final duty = duties.first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    duty.dutyCode,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                                  ),
                                  StatusBadge(status: duty.status),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dutyInfoTile('Vehicle Plate', duty.assignedVehicle, Icons.directions_bus),
                                  ),
                                  Expanded(
                                    child: _dutyInfoTile('Shift Window', '${duty.startTime} - ${duty.endTime}', Icons.access_time),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dutyInfoTile('Driving Time', '${duty.totalDrivingMinutes} min', Icons.timer),
                                  ),
                                  Expanded(
                                    child: _dutyInfoTile('Break Window', '11:55 - 12:40 (45m)', Icons.free_breakfast),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => context.go('/driver/checkin'),
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan Bus QR Code Check-In'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.operationalTeal,
                                  minimumSize: const Size.fromHeight(44),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/navigation', extra: {
                                  'vehicle_id': duty.assignedVehicle,
                                  'route_number': 'R101',
                                  'route_name': 'Downtown Express',
                                  'destination_lat': 40.7071,
                                  'destination_lng': -74.0090,
                                }),
                                icon: const Icon(Icons.navigation_rounded),
                                label: const Text('Start Route Navigation (Turn-by-Turn GPS)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/driver/incident'),
                              icon: const Icon(Icons.warning_amber_rounded, color: AppColors.criticalRed, size: 18),
                              label: const Text('Report Issue', style: TextStyle(color: AppColors.criticalRed, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/driver/swap'),
                              icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.accentBlue, size: 18),
                              label: const Text('Request Swap', style: TextStyle(color: AppColors.accentBlue, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Assigned Trip Manifest',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(height: 8),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: duty.trips.length,
                        itemBuilder: (context, index) {
                          final t = duty.trips[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryNavy.withOpacity(0.08),
                                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                              ),
                              title: Text(t['trip_number'] ?? 'Trip #${index+1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                '${t['route']} • Departure: ${t['start_time']} -> Arrival: ${t['end_time']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading duties: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dutyInfoTile(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryNavySlate),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          ],
        ),
      ],
    );
  }
}
