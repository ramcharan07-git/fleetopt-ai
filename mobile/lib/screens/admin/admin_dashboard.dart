import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/providers/providers.dart';
import 'package:fleetopt_ai/widgets/app_drawer.dart';
import 'package:fleetopt_ai/widgets/kpi_card.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FleetOpt AI • Admin Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(analyticsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.go('/map'),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(analyticsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Operations Overview',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryNavy),
                      ),
                      Text(
                        'Autonomous Public Fleet & Rostering Optimization',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                  const StatusBadge(status: 'ACTIVE'),
                ],
              ),
              const SizedBox(height: 18),

              // KPI Metric Cards Grid
              analyticsAsync.when(
                data: (data) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: KpiCard(
                            title: 'Active Buses',
                            value: '${data.activeBuses} / ${data.availableBuses}',
                            subtitle: '${data.fleetUtilizationRate}% Fleet Utilized',
                            icon: Icons.directions_bus_rounded,
                            color: AppColors.primaryNavy,
                            onTap: () => context.go('/admin/fleet'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KpiCard(
                            title: 'Drivers on Duty',
                            value: '${data.driversOnDuty} / ${data.availableDrivers}',
                            subtitle: '${data.driverUtilizationRate}% Crew Utilized',
                            icon: Icons.badge_rounded,
                            color: AppColors.operationalTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: KpiCard(
                            title: 'Trip Coverage',
                            value: '${data.coveredTrips} / ${data.totalTrips}',
                            subtitle: data.uncoveredTrips > 0 ? '${data.uncoveredTrips} Uncovered Trips' : '100% Fully Covered',
                            icon: Icons.schedule_rounded,
                            color: data.uncoveredTrips > 0 ? AppColors.warningOrange : AppColors.operationalGreen,
                            onTap: () => context.go('/admin/optimize'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KpiCard(
                            title: 'Operating Cost',
                            value: '\$${data.totalOperatingCost.toStringAsFixed(0)}',
                            subtitle: '${data.breakdownCount} Active Breakdowns',
                            icon: Icons.attach_money_rounded,
                            color: AppColors.accentBlue,
                            onTap: () => context.go('/admin/analytics'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (err, _) => Card(
                  color: AppColors.criticalRed.withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Failed to load metrics: $err', style: const TextStyle(color: AppColors.criticalRed)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Optimization Action Hero Card
              Card(
                color: AppColors.primaryNavy,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.auto_awesome, color: AppColors.operationalTeal, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Google OR-Tools CP-SAT Optimizer',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Generate mathematically optimal vehicle assignments and driver duty rosters satisfying union rest periods, duty limits, and deadhead buffer times.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => context.go('/admin/optimize'),
                            icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryNavy),
                            label: const Text('Open Optimizer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/admin/simulate'),
                            icon: const Icon(Icons.science_outlined, color: Colors.white),
                            label: const Text('What-If Simulator', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Access Hub
              const Text(
                'Operational Management Modules',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 12),
              _buildModuleTile(
                context,
                title: 'Fleet & Vehicle Defect Registry',
                subtitle: 'Manage 30 buses, maintenance schedules, and depot allocation',
                icon: Icons.directions_bus_filled,
                route: '/admin/fleet',
              ),
              _buildModuleTile(
                context,
                title: 'Live Transit GPS Map (OSM)',
                subtitle: 'Track real-time bus locations, speeds, and active route lines',
                icon: Icons.map_rounded,
                route: '/map',
              ),
              _buildModuleTile(
                context,
                title: 'Demand Prediction & Intelligence',
                subtitle: 'Scikit-Learn Random Forest regression passenger forecasting',
                icon: Icons.insights_rounded,
                route: '/admin/analytics',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryNavy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryNavy),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go(route),
      ),
    );
  }
}
