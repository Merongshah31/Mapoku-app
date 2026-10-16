import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/header.dart';
import 'new_report_screen.dart';
import 'report_card.dart';
import 'report_detail_screen.dart';

/// Report tab: what the community has reported nearby, and your own reports.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  Future<void> _newReport(BuildContext context) async {
    final receipt = await Navigator.of(context, rootNavigator: true).push<ReportReceipt>(
      CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const NewReportScreen()),
    );
    if (receipt == null || !context.mounted) return;
    context.read<ReportsController>().addMine(receipt.report);
    _showSent(context, receipt);
  }

  void _showSent(BuildContext context, ReportReceipt r) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.checkmark_circle_fill, size: 56, color: Palette.moss),
            const SizedBox(height: 12),
            const Text('Report sent', style: TextStyles.title2),
            const SizedBox(height: 8),
            Text(
              'You got ${r.pointsNow} points. You\'ll get ${r.pointsOnConfirm} more when other users confirm it. '
              'Track it under My reports.',
              textAlign: TextAlign.center,
              style: TextStyles.subhead,
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReportsController>();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final reports = c.visible;
    final mine = c.feed == ReportsFeed.mine;

    return CustomScrollView(
      slivers: [
        const TabHeader(title: 'Report'),
        CupertinoSliverRefreshControl(onRefresh: c.load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.list(
            children: [
              PrimaryButton(
                label: 'Report an obstacle',
                icon: CupertinoIcons.plus,
                onPressed: () => _newReport(context),
              ),
              const SizedBox(height: 20),
              SegmentTabs<ReportsFeed>(
                value: c.feed,
                onChanged: c.show,
                items: {
                  ReportsFeed.community: ('Community', null),
                  ReportsFeed.mine: ('My reports', c.mine.length),
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  mine
                      ? 'You get 40 points when a report is confirmed by others.'
                      : 'Reports near you. Tell others if a barrier is still there.',
                  style: TextStyles.footnote,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        if (c.loading && reports.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(40), child: CupertinoActivityIndicator()),
          )
        else if (c.error != null && reports.isEmpty)
          SliverToBoxAdapter(child: _Empty(text: c.error!))
        else if (reports.isEmpty)
          SliverToBoxAdapter(
            child: _Empty(
              text: mine ? "You haven't reported anything yet." : 'No reports near you yet.',
              action: mine ? () => _newReport(context) : null,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 24),
            sliver: SliverList.separated(
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => ReportCard(
                report: reports[i],
                mine: mine,
                onTap: () => ReportDetailScreen.open(context, reports[i], mine: mine),
                onVote: mine ? null : (stillThere) => c.vote(reports[i], stillThere: stillThere),
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.action});

  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
        child: Column(
          children: [
            const Icon(CupertinoIcons.map, size: 40, color: Palette.tertiary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyles.subhead),
            if (action != null) ...[
              const SizedBox(height: 12),
              Pressable(
                onTap: action,
                semanticLabel: 'Report an obstacle',
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Report an obstacle', style: TextStyles.body.copyWith(color: Palette.moss)),
                ),
              ),
            ],
          ],
        ),
      );
}
