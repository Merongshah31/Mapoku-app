import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sime_darby_hub.dart';
import '../services/accessible_pathfinder.dart';

/// Live hackathon metrics for the active route.
///
/// Shows the township name and category, distance and estimated walk time,
/// the accessibility score and the covered-walkway percentage — all recomputed
/// from the A* result whenever the mode or the simulated obstacle changes.
class RouteMetricsCard extends StatelessWidget {
  const RouteMetricsCard({
    super.key,
    required this.hub,
    required this.result,
    required this.accessibilityMode,
    required this.obstacleActive,
    required this.rerouted,
  });

  final SimeDarbyHub hub;
  final PathResult result;
  final bool accessibilityMode;
  final bool obstacleActive;
  final bool rerouted;

  @override
  Widget build(BuildContext context) {
    final stepFree = result.stepFree;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.sdpCharcoal,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hub.name.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.sdpRed,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hub.metricsSubtitle,
                      style: const TextStyle(
                        color: AppColors.sdpGreyMid,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _ModeBadge(accessibilityMode: accessibilityMode),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hub.focusArea,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetricTile(
                label: 'DISTANCE',
                value: AccessiblePathfinder.formatDistance(result.distanceMeters),
                accent: AppColors.sdpRed,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                label: 'WALK TIME',
                value: AccessiblePathfinder.formatMinutes(result.walkMinutes),
                accent: AppColors.sdpRed,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                label: 'ACCESSIBILITY',
                value: '${result.accessibilityScore}%',
                accent: stepFree ? AppColors.routeAccessible : AppColors.construction,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CoveredBar(percent: result.coveredPercent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: stepFree ? Icons.check_circle : Icons.warning_amber_rounded,
                label: stepFree ? '100% Step-Free' : 'Includes stairs',
                color: stepFree ? AppColors.routeAccessible : AppColors.construction,
              ),
              _StatusPill(
                icon: Icons.umbrella,
                label: '${result.coveredPercent.round()}% Covered',
                color: Colors.white,
              ),
              if (obstacleActive)
                const _StatusPill(
                  icon: Icons.alt_route,
                  label: 'REROUTED',
                  color: AppColors.construction,
                )
              else if (rerouted)
                const _StatusPill(
                  icon: Icons.alt_route,
                  label: 'DETOUR ACTIVE',
                  color: AppColors.construction,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.accessibilityMode});

  final bool accessibilityMode;

  @override
  Widget build(BuildContext context) {
    final color = accessibilityMode ? AppColors.routeAccessible : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(accessibilityMode ? Icons.accessible : Icons.directions_walk, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            accessibilityMode ? 'OKU' : 'STANDARD',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.sdpGreyMid,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoveredBar extends StatelessWidget {
  const _CoveredBar({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.umbrella, size: 13, color: AppColors.sdpGreyMid),
            const SizedBox(width: 6),
            const Text(
              'Covered walkway',
              style: TextStyle(
                color: AppColors.sdpGreyMid,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${percent.round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: (percent / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.routeAccessible),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}