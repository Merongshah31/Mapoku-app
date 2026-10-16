import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import 'common.dart';

/// One icon per obstacle kind, used on the map, in lists and on the Report grid.
IconData obstacleIcon(ObstacleKind k) => switch (k) {
      ObstacleKind.noRamp => Icons.stairs_outlined,
      ObstacleKind.liftBroken => Icons.elevator_outlined,
      ObstacleKind.escalatorBroken => Icons.escalator_outlined,
      ObstacleKind.pathBlocked => Icons.construction_outlined,
      ObstacleKind.unevenSurface => Icons.terrain_outlined,
      ObstacleKind.narrowPath => Icons.compare_arrows,
      ObstacleKind.steepSlope => Icons.trending_up,
      ObstacleKind.noDroppedKerb => Icons.straighten_outlined,
      ObstacleKind.noTactilePaving => Icons.texture,
      ObstacleKind.parkingMisused => Icons.local_parking_outlined,
      ObstacleKind.toiletUnavailable => Icons.wc_outlined,
      ObstacleKind.heavyDoor => Icons.door_front_door_outlined,
      ObstacleKind.flooding => Icons.flood_outlined,
      ObstacleKind.poorLighting => Icons.lightbulb_outline,
      ObstacleKind.other => Icons.more_horiz,
    };

String reportedLine(Obstacle o) {
  final people = o.confirmations == 1 ? '1 person' : '${o.confirmations} people';
  return 'Reported ${timeAgo(o.reportedAt)}, confirmed by $people';
}

/// List row for a reported obstacle.
class ObstacleRow extends StatelessWidget {
  const ObstacleRow({super.key, required this.obstacle, this.onTap});

  final Obstacle obstacle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: '${obstacle.title}. ${reportedLine(obstacle)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Palette.amberSoft, shape: BoxShape.circle),
              child: Icon(obstacleIcon(obstacle.kind), size: 20, color: Palette.amberText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(obstacle.title, style: TextStyles.callout),
                  const SizedBox(height: 2),
                  Text(reportedLine(obstacle), style: TextStyles.footnote),
                ],
              ),
            ),
            if (onTap != null) const Icon(CupertinoIcons.chevron_right, size: 16, color: Palette.tertiary),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for an obstacle: details plus "Is it still there?".
/// Each answer is sent to the backend so stale reports age out.
Future<void> showObstacleSheet(BuildContext context, Obstacle o) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ObstacleSheet(obstacle: o, repo: context.read<MapokuRepository>()),
  );
}

class _ObstacleSheet extends StatefulWidget {
  const _ObstacleSheet({required this.obstacle, required this.repo});

  final Obstacle obstacle;
  final MapokuRepository repo;

  @override
  State<_ObstacleSheet> createState() => _ObstacleSheetState();
}

class _ObstacleSheetState extends State<_ObstacleSheet> {
  bool? _answer; // null = not answered yet
  bool _sending = false;

  Future<void> _send(bool stillThere) async {
    setState(() => _sending = true);
    await widget.repo.confirmObstacle(widget.obstacle.id, stillThere: stillThere);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _answer = stillThere;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.obstacle;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Palette.amberSoft, shape: BoxShape.circle),
                child: Icon(obstacleIcon(o.kind), color: Palette.amberText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.title, style: TextStyles.headline),
                    const SizedBox(height: 2),
                    Text(reportedLine(o), style: TextStyles.footnote),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_answer == null) ...[
            Text('Is it still there?', style: TextStyles.subhead.copyWith(color: Palette.ink)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Still there',
                    loading: _sending,
                    onPressed: _sending ? null : () => _send(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OutlineButton(label: "It's gone", onPressed: _sending ? null : () => _send(false)),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(CupertinoIcons.checkmark_circle_fill, color: Palette.moss),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _answer! ? 'Thanks. Others will see it was confirmed just now.' : "Thanks. We'll mark it as cleared once others agree.",
                    style: TextStyles.callout,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onPressed,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.field,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Text(label, style: TextStyles.headline.copyWith(color: Palette.ink)),
        ),
      );
}
