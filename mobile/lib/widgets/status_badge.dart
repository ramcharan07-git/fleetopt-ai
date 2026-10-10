import 'package:flutter/material.dart';
import 'package:fleetopt_ai/config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'optimal':
      case 'verified':
      case 'completed':
      case 'operational':
        bg = AppColors.operationalGreen.withValues(alpha: 0.12);
        fg = AppColors.operationalGreen;
        break;
      case 'feasible':
      case 'assigned':
      case 'moderate':
      case 'in_progress':
      case 'moderate_load':
        bg = AppColors.operationalTeal.withValues(alpha: 0.15);
        fg = AppColors.operationalTeal;
        break;
      case 'maintenance':
      case 'draft':
      case 'pending':
      case 'warning':
      case 'high':
        bg = AppColors.warningOrange.withValues(alpha: 0.15);
        fg = AppColors.warningOrange;
        break;
      case 'breakdown':
      case 'infeasible':
      case 'uncovered':
      case 'cancelled':
      case 'critical':
      case 'surge':
        bg = AppColors.criticalRed.withValues(alpha: 0.15);
        fg = AppColors.criticalRed;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.12);
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
