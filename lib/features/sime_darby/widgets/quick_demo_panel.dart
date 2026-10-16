import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// "Quick Demo Scenarios" panel for hackathon judges.
///
/// - toggles between the standard pedestrian route and the OKU / wheelchair
///   route (which recalculates the A* path in real time)
/// - simulates a construction / blocked path and re-routes around it
class QuickDemoPanel extends StatelessWidget {
  const QuickDemoPanel({
    super.key,
    required this.accessibilityMode,
    required this.onModeChanged,
    required this.obstacleActive,
    required this.onToggleObstacle,
    required this.onReset,
  });

  final bool accessibilityMode;
  final ValueChanged<bool> onModeChanged;
  final bool obstacleActive;
  final VoidCallback onToggleObstacle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sdpCharcoal,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.sdpRed.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 18, color: AppColors.sdpRed),
              const SizedBox(width: 8),
              const Text(
                'QUICK DEMO SCENARIOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'ROUTE MODE',
            style: TextStyle(
              color: AppColors.sdpGreyMid,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          _ModeToggle(value: accessibilityMode, onChanged: onModeChanged),
          const SizedBox(height: 16),
          _ObstacleButton(active: obstacleActive, onPressed: onToggleObstacle),
          const SizedBox(height: 10),
          Text(
            obstacleActive
                ? 'Barrier placed on the active walkway — A* re-routed the path.'
                : 'Place a temporary 3D barrier and watch the path re-route live.',
            style: const TextStyle(color: AppColors.sdpGreyMid, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 34),
              ),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset scenario', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ModeOption(
            label: 'Standard',
            icon: Icons.directions_walk,
            selected: !value,
            onTap: () => onChanged(false),
          ),
          _ModeOption(
            label: 'OKU / Wheelchair',
            icon: Icons.accessible,
            selected: value,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.sdpRed : Colors.transparent;
    final foreground = selected ? Colors.white : AppColors.sdpGreyMid;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObstacleButton extends StatelessWidget {
  const _ObstacleButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: active ? AppColors.sdpCharcoalSoft : AppColors.construction,
          foregroundColor: active ? Colors.white : AppColors.sdpCharcoal,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: active ? AppColors.construction : Colors.transparent,
              width: 1.6,
            ),
          ),
        ),
        icon: Icon(active ? Icons.undo : Icons.construction, size: 18),
        label: Text(
          active ? 'Remove obstacle' : 'Simulate Construction / Blocked Path',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}