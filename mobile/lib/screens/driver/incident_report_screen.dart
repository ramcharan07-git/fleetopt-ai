import 'package:flutter/material.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/services/api_service.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  String _incidentType = 'delay';
  final _descController = TextEditingController();
  final _busPlateController = TextEditingController(text: 'BUS-101');
  String _severity = 'medium';
  bool _isSubmitting = false;

  void _submit() async {
    if (_descController.text.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      await apiService.reportIncident(
        incidentType: _incidentType,
        vehicleId: _busPlateController.text.trim(),
        description: _descController.text.trim(),
        severity: _severity,
      );
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disruption reported. Control room notified for rescheduling!'),
            backgroundColor: AppColors.operationalGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report failed: $e'), backgroundColor: AppColors.criticalRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Service Disruption'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Disruption Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _incidentType,
                      items: const [
                        DropdownMenuItem(value: 'delay', child: Text('Traffic Delay / Roadblock')),
                        DropdownMenuItem(value: 'breakdown', child: Text('Mechanical Breakdown')),
                        DropdownMenuItem(value: 'accident', child: Text('Accident / Minor Collision')),
                        DropdownMenuItem(value: 'absence', child: Text('Emergency Driver Absence')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _incidentType = val);
                      },
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Vehicle Plate Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _busPlateController,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.directions_bus_outlined)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Severity Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _severity,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low (Minor Delay < 10m)')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium (15-30m Delay)')),
                        DropdownMenuItem(value: 'high', child: Text('High (Vehicle Immobile)')),
                        DropdownMenuItem(value: 'critical', child: Text('Critical (Immediate Evacuation)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _severity = val);
                      },
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.warning_amber_rounded)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Description & Situation Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Describe location, route, symptoms or estimated delay duration...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(_isSubmitting ? 'Transmitting to Control Room...' : 'Submit Disruption Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.criticalRed,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
