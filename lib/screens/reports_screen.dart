import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/obstacle.dart';
import '../models/report.dart';
import '../state/app_scope.dart';
import '../widgets/health_status.dart';
import '../widgets/report_card.dart';
import '../widgets/report_obstacle_sheet.dart';

/// Community obstacle feed and personal report history.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _segment = 0; // 0 = community, 1 = my reports

  Report _toReport(Obstacle obstacle) => Report(
        id: obstacle.id,
        type: obstacle.type.label,
        icon: obstacle.type.icon,
        location: obstacle.location,
        description: obstacle.description,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        confirmations: obstacle.confirms,
        clearances: obstacle.clearances,
      );

  void _openReportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ReportObstacleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final community = state.communityObstacles;
    final mine = state.myReports;
    final list = _segment == 0 ? community : mine;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reports', style: Theme.of(context).textTheme.headlineMedium),
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
            _SegmentedControl(
              index: _segment,
              onChanged: (value) => setState(() => _segment = value),
            ),
            const SizedBox(height: 12),
            if (_segment == 1)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _openReportSheet,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New report'),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? _EmptyState(isMine: _segment == 1)
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (_segment == 0) {
                          final obstacle = community[index];
                          return ReportCard(
                            report: _toReport(obstacle),
                            onConfirm: () => state.confirmObstacle(obstacle.id),
                            onClear: () => state.clearObstacle(obstacle.id),
                          );
                        }
                        return ReportCard(report: mine[index], isMine: true);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Community', 'My reports'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: i == index
                        ? const [BoxShadow(color: Color(0x141E2B22), blurRadius: 6, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: i == index ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isMine});

  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            isMine ? 'No reports yet.' : 'No community reports nearby.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            isMine ? 'Start by reporting an obstacle!' : 'You are all clear — for now.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}