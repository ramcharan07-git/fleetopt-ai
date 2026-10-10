import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/services/api_service.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  double _availableBuses = 28;
  double _absentDrivers = 2;
  double _demandPercentage = 100.0;
  double _breakdowns = 1;
  bool _isLoading = false;
  Map<String, dynamic>? _simResult;
  String? _error;

  void _runSimulation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await apiService.simulateWhatIf(
        date: dateStr,
        availableBuses: _availableBuses.toInt(),
        absentDrivers: _absentDrivers.toInt(),
        demandPercentage: _demandPercentage,
        vehicleBreakdowns: _breakdowns.toInt(),
      );
      setState(() {
        _simResult = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What-If Scenario Simulator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simulation Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.science_rounded, color: AppColors.operationalTeal),
                        SizedBox(width: 8),
                        Text(
                          'Scenario Perturbation Controls',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      'Available Active Buses: ${_availableBuses.toInt()} buses',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Slider(
                      value: _availableBuses,
                      min: 15,
                      max: 30,
                      divisions: 15,
                      label: '${_availableBuses.toInt()}',
                      activeColor: AppColors.primaryNavy,
                      onChanged: (val) => setState(() => _availableBuses = val),
                    ),
                    Text(
                      'Driver Absenteeism: ${_absentDrivers.toInt()} absent drivers',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Slider(
                      value: _absentDrivers,
                      min: 0,
                      max: 15,
                      divisions: 15,
                      label: '${_absentDrivers.toInt()}',
                      activeColor: AppColors.warningOrange,
                      onChanged: (val) => setState(() => _absentDrivers = val),
                    ),
                    Text(
                      'Passenger Demand Surge: ${_demandPercentage.toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Slider(
                      value: _demandPercentage,
                      min: 70,
                      max: 160,
                      divisions: 9,
                      label: '${_demandPercentage.toInt()}%',
                      activeColor: AppColors.accentBlue,
                      onChanged: (val) => setState(() => _demandPercentage = val),
                    ),
                    Text(
                      'Simulated Bus Breakdowns: ${_breakdowns.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Slider(
                      value: _breakdowns,
                      min: 0,
                      max: 5,
                      divisions: 5,
                      label: '${_breakdowns.toInt()}',
                      activeColor: AppColors.criticalRed,
                      onChanged: (val) => setState(() => _breakdowns = val),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runSimulation,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.play_circle_outline),
                      label: Text(_isLoading ? 'Simulating Perturbations...' : 'Execute What-If Scenario Solver'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null)
              Card(
                color: AppColors.criticalRed.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Simulation Error: $_error', style: const TextStyle(color: AppColors.criticalRed)),
                ),
              ),

            // Simulation Comparative Output
            if (_simResult != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Simulation Impact Comparison',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                          StatusBadge(status: _simResult!['uncovered_trips_count'] > 0 ? 'WARNING' : 'OPTIMAL'),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        'Solved in ${_simResult!['solve_time_seconds']}s without altering live production schedules.',
                        style: const TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _statBox(
                              'Trips Covered',
                              '${_simResult!['simulated_covered']}',
                              'Baseline: ${_simResult!['baseline_covered']}',
                              color: AppColors.operationalGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statBox(
                              'Uncovered Trips',
                              '${_simResult!['uncovered_trips_count']}',
                              _simResult!['uncovered_trips_count'] > 0 ? 'Resource Deficit' : 'Full Service',
                              color: _simResult!['uncovered_trips_count'] > 0 ? AppColors.criticalRed : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statBox(
                              'Operating Cost',
                              '\$${(_simResult!['simulated_cost'] as num).toStringAsFixed(0)}',
                              'Baseline: \$${(_simResult!['baseline_cost'] as num).toStringAsFixed(0)}',
                              color: AppColors.accentBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statBox(
                              'Active Fleet',
                              '${_simResult!['active_buses']} Buses',
                              '${_simResult!['active_drivers']} Drivers',
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox(String title, String val, String sub, {required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
