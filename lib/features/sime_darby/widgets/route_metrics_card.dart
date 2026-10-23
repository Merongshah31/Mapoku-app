import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sime_darby_hub.dart';
import '../services/accessible_pathfinder.dart';

/// Live metrics for the active route.
///
/// Distance, walk time, accessibility score and covered-walkway percentage,
/// all recomputed from the A* result whenever the mode or the simulated
/// obstacle changes.
class RouteMetricsCard extends StatelessWidget {
  const RouteMetricsCard({
    super.key,
    required this.hub,
    required this.result,
    required this.accessibilityMode,
    this.avoidedHazards = 0,
    this.hazardsOnRoute = 0,
  });

  final SimeDarbyHub hub;
  final PathResult result;
  final bool accessibilityMode;

  /// Reported obstacles the route was bent around.
  final int avoidedHazards;

  /// Reported obstacles the route still has to pass.
  final int hazardsOnRoute;

  @override
  Widget build(BuildContext context) {
    if (result.nodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: <Widget>[
            const Icon(CupertinoIcons.location_slash, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                accessibilityMode
                    ? 'No step-free route between these points right now.'
                    : 'No walking route between these points right now.',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final stepFree = result.stepFree;
    final scoreColor = stepFree ? AppColors.success : AppColors.accentText;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hub.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hub.metricsSubtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _ModeBadge(accessibilityMode: accessibilityMode),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hub.focusArea,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _MetricTile(
                label: 'Distance',
                value: AccessiblePathfinder.formatDistance(
                  result.distanceMeters,
                ),
                accent: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                label: 'Walk time',
                value: AccessiblePathfinder.formatMinutes(result.walkMinutes),
                accent: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                label: 'Access score',
                value: '${result.accessibilityScore}%',
                accent: scoreColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CoveredBar(percent: result.coveredPercent),
          const SizedBox(height: 14),
          _SensorySummary(result: result),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusPill(
                icon: stepFree
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.exclamationmark_triangle_fill,
                label: stepFree ? 'Step-free' : 'Includes stairs',
                color: stepFree ? AppColors.success : AppColors.danger,
              ),
              _StatusPill(
                icon: Icons.umbrella,
                label: '${result.coveredPercent.round()}% covered',
                color: AppColors.primary,
              ),
              if (hazardsOnRoute > 0)
                _StatusPill(
                  icon: CupertinoIcons.exclamationmark_triangle_fill,
                  label: hazardsOnRoute == 1
                      ? 'Passes 1 reported obstacle'
                      : 'Passes $hazardsOnRoute reported obstacles',
                  color: AppColors.danger,
                )
              else if (avoidedHazards > 0)
                _StatusPill(
                  icon: Icons.alt_route,
                  label: avoidedHazards == 1
                      ? 'Rerouted around 1 report'
                      : 'Rerouted around $avoidedHazards reports',
                  color: AppColors.accentText,
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
    final color = accessibilityMode
        ? AppColors.primary
        : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accessibilityMode ? AppColors.mint : AppColors.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            accessibilityMode ? Icons.accessible : Icons.directions_walk,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            accessibilityMode ? 'OKU route' : 'Standard',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
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
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.umbrella,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Covered walkway',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${percent.round()}%',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: (percent / 100).clamp(0.0, 1.0),
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: AppColors.field,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sensory read-out for the active route: noise, light, tactile paving and
/// buggy access — the four extra things the extended mapOKU profiles care about.
class _SensorySummary extends StatelessWidget {
  const _SensorySummary({required this.result});

  final PathResult result;

  @override
  Widget build(BuildContext context) {
    final noise = result.worstNoise;
    final light = result.worstLight;
    final tactile = result.tactilePercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: const <Widget>[
            Icon(Icons.graphic_eq, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text(
              'Sensory profile',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _StatusPill(
              icon: noise.isLoud ? Icons.volume_up : Icons.volume_off,
              label: '${noise.label} · ${noise.db} dB',
              color: noise.isLoud ? AppColors.danger : AppColors.success,
            ),
            _StatusPill(
              icon: light.isHarsh ? Icons.wb_sunny : Icons.umbrella,
              label: light.label,
              color: light.isHarsh
                  ? AppColors.construction
                  : AppColors.success,
            ),
            _StatusPill(
              icon: Icons.touch_app,
              label: tactile >= 99
                  ? 'Tactile paving throughout'
                  : '${tactile.round()}% tactile paving',
              color: tactile >= 60 ? AppColors.primary : AppColors.accentText,
            ),
            _StatusPill(
              icon: Icons.airport_shuttle,
              label: result.buggyFriendly
                  ? 'Buggy-ready route'
                  : 'Not buggy accessible',
              color: result.buggyFriendly
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

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
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
