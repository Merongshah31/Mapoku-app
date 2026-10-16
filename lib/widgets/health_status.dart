import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../state/app_state.dart';

/// Live backend health indicator (same idea as the web footer).
class HealthStatus extends StatelessWidget {
  const HealthStatus({super.key, required this.health});

  final ServiceHealth health;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (health) {
      ServiceHealth.checking => (AppColors.textTertiary, 'Checking service'),
      ServiceHealth.online => (AppColors.primary, 'Services online'),
      ServiceHealth.offline => (AppColors.accent, 'Demo mode (offline)'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}