import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/models/models.dart';
import 'package:fleetopt_ai/services/api_service.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class OptimizationScreen extends StatefulWidget {
  const OptimizationScreen({super.key});

  @override
  State<OptimizationScreen> createState() => _OptimizationScreenState();
}

class _OptimizationScreenState extends State<OptimizationScreen> {
  DateTime _selectedDate = DateTime.now();
  double _maxDutyHours = 8.0;
  double _minRestHours = 11.0;
  bool _isLoading = false;
  OptimizationResultModel? _result;
  String? _errorMessage;
  bool _isApproved = false;

  void _runOptimizer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isApproved = false;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await apiService.runOptimization(
        date: dateStr,
        maxDutyHours: _maxDutyHours,
        minRestHours: _minRestHours,
      );
      setState(() {
        _result = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _approveSchedule() async {
    if (_result == null) return;
    try {
      await apiService.approveSchedule(_result!.scheduleId, notes: 'Approved via Mobile Admin');
      setState(() => _isApproved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule officially APPROVED and locked into MySQL!'),
            backgroundColor: AppColors.operationalGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e'), backgroundColor: AppColors.criticalRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet & Duty Optimizer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Optimizer Configuration Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded, color: AppColors.primaryNavy),
                        SizedBox(width: 8),
                        Text(
                          'CP-SAT Optimization Parameters',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryNavySlate),
                      title: const Text('Schedule Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        child: const Text('Change Date'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Max Driver Duty Duration: ${_maxDutyHours.toStringAsFixed(1)} hours',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Slider(
                      value: _maxDutyHours,
                      min: 6.0,
                      max: 12.0,
                      divisions: 12,
                      label: '${_maxDutyHours.toStringAsFixed(1)}h',
                      activeColor: AppColors.primaryNavy,
                      onChanged: (val) => setState(() => _maxDutyHours = val),
                    ),
                    Text(
                      'Min Mandatory Rest Duration: ${_minRestHours.toStringAsFixed(1)} hours',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Slider(
                      value: _minRestHours,
                      min: 8.0,
                      max: 14.0,
                      divisions: 12,
                      label: '${_minRestHours.toStringAsFixed(1)}h',
                      activeColor: AppColors.operationalTeal,
                      onChanged: (val) => setState(() => _minRestHours = val),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runOptimizer,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.rocket_launch_rounded),
                      label: Text(_isLoading ? 'Solving Mathematical Model...' : 'Execute Combinatorial Optimization'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Card(
                color: AppColors.criticalRed.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Solver Error: $_errorMessage', style: const TextStyle(color: AppColors.criticalRed)),
                ),
              ),

            // Optimizer Output View
            if (_result != null) ...[
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
                            'Optimization Results',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                          ),
                          StatusBadge(status: _result!.solverStatus),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        _result!.explanation ?? 'Solved successfully.',
                        style: const TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _badge('Solved in ${_result!.solveDurationSeconds.toStringAsFixed(2)}s', Icons.timer_outlined),
                          _badge('${_result!.coveredTrips}/${_result!.totalTrips} Covered', Icons.check_circle_outline, color: AppColors.operationalGreen),
                          _badge('${_result!.uncoveredTrips} Uncovered', Icons.warning_amber_rounded, color: _result!.uncoveredTrips > 0 ? AppColors.criticalRed : Colors.grey),
                          _badge('${_result!.vehiclesUsed} Buses', Icons.directions_bus_outlined),
                          _badge('${_result!.driversUsed} Drivers', Icons.badge_outlined),
                          _badge('Cost: \$${_result!.estimatedCost.toStringAsFixed(0)}', Icons.payments_outlined),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isApproved ? null : _approveSchedule,
                              icon: Icon(_isApproved ? Icons.verified : Icons.thumb_up_alt_rounded),
                              label: Text(_isApproved ? 'Schedule Approved' : 'Approve & Lock Schedule'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isApproved ? Colors.grey : AppColors.operationalGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Trip & Crew Assignment Manifest',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _result!.assignments.length,
                itemBuilder: (context, index) {
                  final a = _result!.assignments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: a.uncovered ? AppColors.criticalRed.withOpacity(0.12) : AppColors.primaryNavy.withOpacity(0.08),
                        child: Icon(
                          a.uncovered ? Icons.close : Icons.check,
                          color: a.uncovered ? AppColors.criticalRed : AppColors.primaryNavy,
                        ),
                      ),
                      title: Text('${a.tripNumber} (${a.routeNumber})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        'Time: ${a.startTime} - ${a.endTime} • Bus: ${a.vehiclePlate ?? "UNASSIGNED"} • Driver: ${a.driverName ?? "UNASSIGNED"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: StatusBadge(status: a.uncovered ? 'UNCOVERED' : 'ASSIGNED'),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, IconData icon, {Color color = AppColors.primaryNavy}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
