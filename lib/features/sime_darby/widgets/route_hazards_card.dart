import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../services/route_hazards.dart';

/// Obstacles the community has reported on this hub's walkways, and what the
/// route did about each one. Reporting a new one is always one tap away, so
/// the card is the way back into the Reports flow, not a simulation switch.
class RouteHazardsCard extends StatelessWidget {
  const RouteHazardsCard({
    super.key,
    required this.hazards,
    required this.onOpen,
    required this.onReport,
  });

  final List<RouteHazard> hazards;
  final ValueChanged<RouteHazard> onOpen;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.report_gmailerrorred,
                  size: 18,
                  color: AppColors.accent,
                ),
                SizedBox(width: 8),
                Text(
                  'Reported by the community',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (hazards.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No reported obstacles on the walkways here.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final hazard in hazards)
              _HazardRow(hazard: hazard, onTap: () => onOpen(hazard)),
          const Divider(height: 1),
          InkWell(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusMd),
            ),
            onTap: onReport,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Report an obstacle here',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HazardRow extends StatelessWidget {
  const _HazardRow({required this.hazard, required this.onTap});

  final RouteHazard hazard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final obstacle = hazard.obstacle;
    final (label, color) = switch (hazard.impact) {
      HazardImpact.onRoute => ('On your route', AppColors.danger),
      HazardImpact.avoided => ('Avoided', AppColors.accent),
      HazardImpact.nearby => ('Not on your route', AppColors.textSecondary),
    };
    final summary = obstacle.description.split('\n').first.trim();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                obstacle.type.icon,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    summary.isEmpty ? obstacle.type.label : summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${obstacle.confirms} still there · ${obstacle.ago}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
