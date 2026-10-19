import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../models/obstacle.dart';
import '../models/report.dart';
import '../state/app_scope.dart';
import '../widgets/health_status.dart';
import '../widgets/report_card.dart';
import '../widgets/ui_kit.dart';
import 'new_report_screen.dart';
import 'report_detail_screen.dart';

enum _Feed { community, mine }

/// Community obstacle feed and personal report history.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Feed _feed = _Feed.community;

  Future<void> _newReport() async {
    final sent = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NewReportScreen(),
      ),
    );
    if (sent != true || !mounted) return;
    setState(() => _feed = _Feed.mine);
    _showSent();
  }

  void _showSent() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 56, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Report sent', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You got ${AppConfig.pointsPerReport} points. You\'ll get '
              '${AppConfig.pointsPerConfirmation} more when other members confirm it. '
              'Track it under My reports.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Report _toReport(Obstacle obstacle) => Report(
    id: obstacle.id,
    type: obstacle.type.label,
    icon: obstacle.type.icon,
    location: obstacle.location,
    description: obstacle.description,
    position: obstacle.position,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    confirmations: obstacle.confirms,
    clearances: obstacle.clearances,
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = _feed == _Feed.mine;
    final reports = mine
        ? state.myReports
        : [
            for (final obstacle in state.communityObstacles)
              _toReport(obstacle),
          ];

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Obstacles reported by OKU users and commuters nearby.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              HealthStatus(health: state.health),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _newReport,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Report an obstacle'),
          ),
          const SizedBox(height: 20),
          SegmentTabs<_Feed>(
            value: _feed,
            onChanged: (value) => setState(() => _feed = value),
            items: {
              _Feed.community: ('Community', null),
              _Feed.mine: ('My reports', state.myReports.length),
            },
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              mine
                  ? 'You get ${AppConfig.pointsPerConfirmation} points when a report is confirmed by others.'
                  : 'Reports near you. Tell others if a barrier is still there.',
              style: kFootnoteStyle,
            ),
          ),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            _EmptyState(isMine: mine, onReport: mine ? _newReport : null)
          else
            for (final report in reports) ...[
              ReportCard(
                report: report,
                mine: mine,
                onTap: () =>
                    ReportDetailScreen.open(context, report, mine: mine),
                onVote: mine
                    ? null
                    : (stillThere) => stillThere
                          ? state.confirmObstacle(report.id)
                          : state.clearObstacle(report.id),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isMine, this.onReport});

  final bool isMine;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        children: [
          const Icon(
            Icons.map_outlined,
            size: 40,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            isMine
                ? "You haven't reported anything yet."
                : 'No community reports nearby.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onReport != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onReport,
              child: const Text('Report an obstacle'),
            ),
          ],
        ],
      ),
    );
  }
}
