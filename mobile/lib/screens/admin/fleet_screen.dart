import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/models/models.dart';
import 'package:fleetopt_ai/providers/providers.dart';
import 'package:fleetopt_ai/services/api_service.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class FleetScreen extends ConsumerStatefulWidget {
  const FleetScreen({super.key});

  @override
  ConsumerState<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends ConsumerState<FleetScreen> {
  String _selectedFilter = 'all';

  void _showDefectDialog(VehicleModel vehicle) {
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report Defect: ${vehicle.plateNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mark vehicle for maintenance or breakdown investigation.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Defect Description', hintText: 'e.g. Brake vibration, coolant leak'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (descController.text.isNotEmpty) {
                await apiService.reportIncident(
                  incidentType: 'breakdown',
                  vehicleId: vehicle.id,
                  description: descController.text,
                  severity: 'high',
                );
                ref.invalidate(vehiclesProvider);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet & Vehicle Registry'),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _filterChip('All Vehicles', 'all'),
                const SizedBox(width: 8),
                _filterChip('Active', 'active'),
                const SizedBox(width: 8),
                _filterChip('Under Maintenance', 'maintenance'),
                const SizedBox(width: 8),
                _filterChip('Breakdown', 'breakdown'),
              ],
            ),
          ),
          Expanded(
            child: vehiclesAsync.when(
              data: (vehicles) {
                final filtered = _selectedFilter == 'all'
                    ? vehicles
                    : vehicles.where((v) => v.status.toLowerCase() == _selectedFilter).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No vehicles matching selected filter.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final v = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryNavy.withOpacity(0.08),
                          child: const Icon(Icons.directions_bus, color: AppColors.primaryNavy),
                        ),
                        title: Text(v.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text(
                          'Odometer: ${v.odometerKm.toStringAsFixed(0)} km • Year: ${v.yearManufactured} • QR: ${v.qrCode ?? "N/A"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge(status: v.status),
                            IconButton(
                              icon: const Icon(Icons.build_outlined, size: 20),
                              tooltip: 'Report Defect',
                              onPressed: () => _showDefectDialog(v),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primaryNavy.withOpacity(0.15),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
    );
  }
}
