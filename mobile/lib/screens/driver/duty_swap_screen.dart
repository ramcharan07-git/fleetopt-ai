import 'package:flutter/material.dart';
import 'package:fleetopt_ai/config/theme.dart';

class DutySwapScreen extends StatefulWidget {
  const DutySwapScreen({super.key});

  @override
  State<DutySwapScreen> createState() => _DutySwapScreenState();
}

class _DutySwapScreenState extends State<DutySwapScreen> {
  final _targetDriverController = TextEditingController(text: 'DRV-002 (Driver #2)');
  final _reasonController = TextEditingController(text: 'Family medical appointment in afternoon');
  bool _isSubmitted = false;

  void _submitSwap() {
    setState(() => _isSubmitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Duty swap request submitted for manager review.'),
        backgroundColor: AppColors.operationalTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Duty Swap Request'),
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
                    const Text('My Current Duty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    const Text('DUTY-NY-MORNING (08:00 - 16:00 • 3 Trips • BUS-101)', style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                    const Divider(height: 24),
                    const Text('Peer Driver to Swap With', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _targetDriverController,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.person_search_rounded)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Reason for Swap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Enter scheduling justification...'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSubmitted ? null : _submitSwap,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(_isSubmitted ? 'Request Pending Approval' : 'Submit Duty Swap Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
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
