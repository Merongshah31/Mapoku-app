import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sime_darby_hub.dart';
import '../services/accessible_pathfinder.dart';

/// Wording for the step that leads to [next].
String stepInstruction(HubNode next) => switch (next.kind) {
  NodeKind.lift => 'Take the lift at ${next.label}',
  NodeKind.ramp => 'Use the ramp at ${next.label}',
  NodeKind.crossing => 'Cross at ${next.label}',
  NodeKind.bridge => 'Take the bridge to ${next.label}',
  _ => 'Head to ${next.label}',
};

IconData stepIcon(HubNode next) => switch (next.kind) {
  NodeKind.lift => Icons.elevator,
  NodeKind.ramp => Icons.ramp_right,
  NodeKind.crossing => Icons.directions_walk,
  _ => Icons.straight,
};

/// Top card while navigating: what to do next and how far it is.
class NavigationBanner extends StatelessWidget {
  const NavigationBanner({
    super.key,
    required this.route,
    required this.step,
    required this.arrivedLabel,
    required this.hazardsAhead,
  });

  final PathResult route;
  final int step;
  final String arrivedLabel;
  final int hazardsAhead;

  bool get _arrived => step >= route.nodes.length - 1;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String detail;
    final IconData icon;

    if (_arrived) {
      title = 'You have arrived';
      detail = arrivedLabel;
      icon = CupertinoIcons.flag_fill;
    } else {
      final next = route.nodes[step + 1];
      title = stepInstruction(next);
      detail = AccessiblePathfinder.formatDistance(
        route.edges[step].lengthMeters,
      );
      icon = stepIcon(next);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        elevation: 6,
        shadowColor: const Color(0x55000000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hazardsAhead > 0 && !_arrived) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hazardsAhead == 1
                            ? '1 reported obstacle on this route'
                            : '$hazardsAhead reported obstacles on this route',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom card while navigating: time left, next step and end controls.
class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.route,
    required this.step,
    required this.onNext,
    required this.onEnd,
    required this.onReport,
  });

  final PathResult route;
  final int step;
  final VoidCallback onNext;
  final VoidCallback onEnd;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final lastStep = route.nodes.length - 1;
    final arrived = step >= lastStep;

    var remaining = 0.0;
    for (var i = step; i < route.edges.length; i++) {
      remaining += route.edges[i].lengthMeters;
    }
    final minutes = remaining <= 0 ? 0.0 : remaining / 72;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x261E2B22),
            blurRadius: 18,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        arrived
                            ? 'Arrived'
                            : AccessiblePathfinder.formatMinutes(minutes),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        arrived
                            ? 'Enjoy your visit'
                            : '${AccessiblePathfinder.formatDistance(remaining)} left · '
                                  'step ${step + 1} of $lastStep',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Report an obstacle here',
                  onPressed: onReport,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentSoft,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(
                    CupertinoIcons.exclamationmark_bubble,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEnd,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(arrived ? 'Done' : 'End'),
                  ),
                ),
                if (!arrived) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(CupertinoIcons.arrow_right, size: 20),
                      label: const Text('Next step'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
