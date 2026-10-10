import 'package:flutter/material.dart';
import 'package:fleetopt_ai/config/theme.dart';
import 'package:fleetopt_ai/services/api_service.dart';
import 'package:fleetopt_ai/widgets/status_badge.dart';

class QrCheckinScreen extends StatefulWidget {
  const QrCheckinScreen({super.key});

  @override
  State<QrCheckinScreen> createState() => _QrCheckinScreenState();
}

class _QrCheckinScreenState extends State<QrCheckinScreen> {
  final _plateController = TextEditingController(text: 'BUS-101');
  bool _isCheckingIn = false;
  Map<String, dynamic>? _checkinResult;
  String? _error;

  void _submitCheckIn(String vehiclePlate) async {
    setState(() {
      _isCheckingIn = true;
      _error = null;
    });

    try {
      final res = await apiService.checkInAttendance(
        vehicleId: vehiclePlate,
        qrCodeHash: 'QR-$vehiclePlate',
      );
      setState(() {
        _checkinResult = res;
        _isCheckingIn = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingIn = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus QR Check-In'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simulated Camera Scanner Viewport
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryNavy, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.white24),
                  // Scanner targeting reticle
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.operationalTeal, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Align Bus Dashboard QR Code',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Scan Action
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bus Vehicle Identification',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _plateController,
                      decoration: const InputDecoration(
                        labelText: 'Scanned Bus Plate / Identifier',
                        prefixIcon: Icon(Icons.directions_bus),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isCheckingIn ? null : () => _submitCheckIn(_plateController.text.trim()),
                      icon: _isCheckingIn
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.verified_user_rounded),
                      label: Text(_isCheckingIn ? 'Verifying with MySQL...' : 'Confirm Duty Check-In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.operationalGreen,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Card(
                color: AppColors.criticalRed.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Verification Failed: $_error', style: const TextStyle(color: AppColors.criticalRed)),
                ),
              ),

            if (_checkinResult != null)
              Card(
                color: AppColors.operationalGreen.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attendance Confirmed',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.operationalGreen),
                          ),
                          StatusBadge(status: _checkinResult!['status'] ?? 'VERIFIED'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _checkinResult!['message'] ?? 'Duty presence recorded.',
                        style: const TextStyle(fontSize: 13, color: AppColors.lightTextPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Timestamp: ${_checkinResult!['check_in_time'] ?? DateTime.now().toIso8601String()}',
                        style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
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
