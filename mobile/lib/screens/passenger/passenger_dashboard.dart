import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/providers/providers.dart';
import 'package:fleetopt_ai/widgets/app_drawer.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class PassengerDashboardScreen extends ConsumerWidget {
  const PassengerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Transit • Schedules & ETA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Live Bus Map',
            onPressed: () => context.go('/map'),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Box
            TextField(
              decoration: InputDecoration(
                hintText: 'Search routes, destinations or stops...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () {},
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Service Status Banner
            Card(
              color: AppColors.operationalGreen.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: AppColors.operationalGreen),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All metro routes operating on normal schedule. Average headway: 12 minutes.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Public Transit Bus Routes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 8),

            routesAsync.when(
              data: (routes) {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final r = routes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.routeNumber,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${r.origin} -> ${r.destination}', style: const TextStyle(fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Next Departure: In 8 mins', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.operationalGreen)),
                                    const StatusBadge(status: 'MODERATE_LOAD'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Distance: ${r.distanceKm} km • Est. Trip Time: ${r.estimatedDurationMinutes} mins',
                                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => context.go('/map'),
                                  icon: const Icon(Icons.navigation_rounded, size: 16),
                                  label: const Text('Track Live Bus on Map', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
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
