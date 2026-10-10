import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/providers/providers.dart';
import 'package:fleetopt_ai/widgets/app_drawer.dart';
import 'package:fleetopt_ai/widgets/kpi_card.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class DepotDashboardScreen extends ConsumerWidget {
  const DepotDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Depot Manager • Central Depot (DEP-CTR)'),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Depot Header Card
            Card(
              color: AppColors.primaryNavy,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Central Transit Depot',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const StatusBadge(status: 'OPERATIONAL'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '100 Grand Concourse • Capacity: 40 Buses • 14 Mechanics on Duty',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    title: 'Depot Fleet',
                    value: '14 Buses',
                    subtitle: '11 Active • 3 Maintenance',
                    icon: Icons.directions_bus,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KpiCard(
                    title: 'Assigned Drivers',
                    value: '16 Drivers',
                    subtitle: '14 Active • 2 On Leave',
                    icon: Icons.badge_rounded,
                    color: AppColors.operationalTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Depot Vehicle Fleet & Maintenance Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 8),

            vehiclesAsync.when(
              data: (vehicles) {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vehicles.take(8).length,
                  itemBuilder: (context, index) {
                    final v = vehicles[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryNavy.withOpacity(0.08),
                          child: const Icon(Icons.directions_bus, color: AppColors.primaryNavy),
                        ),
                        title: Text(v.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Odometer: ${v.odometerKm.toStringAsFixed(0)} km • QR: ${v.qrCode}'),
                        trailing: StatusBadge(status: v.status),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
