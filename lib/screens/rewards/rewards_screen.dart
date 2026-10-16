import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/header.dart';
import 'redeem_sheet.dart';

enum _View { rewards, vouchers, history }

/// Rewards tab: balance, ways to earn, rewards to redeem, your vouchers,
/// and where your points came from.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  _View _view = _View.rewards;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      slivers: [
        const TabHeader(title: 'Rewards'),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
          sliver: SliverList.list(
            children: [
              if (app.summary == null)
                const Padding(padding: EdgeInsets.all(48), child: CupertinoActivityIndicator())
              else ...[
                _Balance(app: app),
                const SectionTitle('Ways to earn'),
                const _WaysToEarn(),
                const SizedBox(height: 24),
                SegmentTabs<_View>(
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                  items: {
                    _View.rewards: ('Redeem', null),
                    _View.vouchers: ('Vouchers', app.vouchers.length),
                    _View.history: ('History', null),
                  },
                ),
                ...switch (_view) {
                  _View.rewards => _rewards(context, app),
                  _View.vouchers => _vouchers(context, app),
                  _View.history => _history(app),
                },
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _rewards(BuildContext context, AppState app) => [
        for (final cat in RewardCategory.values)
          if (app.rewards.any((r) => r.category == cat)) ...[
            SectionTitle(cat.label),
            Group(
              dividerIndent: 68,
              children: [
                for (final r in app.rewards.where((r) => r.category == cat))
                  _RewardRow(
                    reward: r,
                    affordable: app.points >= r.cost,
                    onTap: () => showRedeemSheet(context, r),
                  ),
              ],
            ),
          ],
        const SectionFooter(
          'You earn points when other users confirm the obstacles you report. '
          'Points only unlock after confirmation, which keeps reports honest. '
          'Partners fund the rewards, so they cost you nothing.',
        ),
      ];

  List<Widget> _vouchers(BuildContext context, AppState app) {
    if (app.vouchers.isEmpty) {
      return [
        const SizedBox(height: 32),
        const Icon(CupertinoIcons.gift, size: 40, color: Palette.tertiary),
        const SizedBox(height: 12),
        const Text(
          'Rewards you redeem are saved here, so you can find the code later.',
          textAlign: TextAlign.center,
          style: TextStyles.subhead,
        ),
      ];
    }
    final now = DateTime.now();
    return [
      const SizedBox(height: 16),
      Group(
        dividerIndent: 68,
        children: [
          for (final v in app.vouchers)
            Pressable(
              semanticLabel: '${v.reward.partnerName} ${v.reward.title}, code ${v.code}',
              onTap: () => showVoucherSheet(context, v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _PartnerIcon(v.reward.partner),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${v.reward.partnerName} ${v.reward.title}', style: TextStyles.body),
                          Text(
                            v.expiresAt.isBefore(now) ? 'Expired' : 'Use by ${shortDate(v.expiresAt)}',
                            style: TextStyles.footnote,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      v.code,
                      style: TextStyles.subhead.copyWith(color: Palette.ink, letterSpacing: 1, fontFeatures: TextStyles.tabular),
                    ),
                    const SizedBox(width: 6),
                    const Icon(CupertinoIcons.chevron_right, size: 16, color: Palette.tertiary),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _history(AppState app) {
    if (app.history.isEmpty) {
      return const [
        SizedBox(height: 32),
        Text('Points you earn and spend will show here.', textAlign: TextAlign.center, style: TextStyles.subhead),
      ];
    }
    return [
      const SizedBox(height: 16),
      Group(
        children: [
          for (final e in app.history)
            Semantics(
              label: '${e.title}, ${e.detail}, ${e.amount > 0 ? 'plus' : 'minus'} ${e.amount.abs()} points, ${timeAgo(e.at)}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: TextStyles.body),
                          Text(e.detail, style: TextStyles.footnote),
                          Text(timeAgo(e.at), style: TextStyles.footnote),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      e.amount > 0 ? '+${e.amount}' : '−${e.amount.abs()}',
                      style: TextStyles.headline.copyWith(
                        color: e.amount > 0 ? Palette.moss : Palette.secondary,
                        fontFeatures: TextStyles.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final s = app.summary!;
    final goal = app.nextGoal;
    final progress = goal == null ? 1.0 : (app.points / goal.cost).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(color: Palette.ink, borderRadius: BorderRadius.circular(Radii.group + 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your points', style: TextStyles.subhead.copyWith(color: Colors.white70)),
          const SizedBox(height: 2),
          Semantics(
            label: '${app.points} points',
            excludeSemantics: true,
            child: Text(
              '${app.points}',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
                fontFeatures: TextStyles.tabular,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF8CC2A0)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goal == null
                ? 'Enough for any reward below.'
                : '${goal.cost - app.points} more for ${goal.partnerName} ${goal.title}',
            style: TextStyles.footnote.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 0.5, color: Color(0x33FFFFFF)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Stat(value: s.reports, label: 'Reports sent')),
              Expanded(child: _Stat(value: s.confirmations, label: 'Confirmed by others')),
              Expanded(child: _Stat(value: app.vouchers.length, label: 'Vouchers')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: TextStyles.title3.copyWith(color: Colors.white, fontFeatures: TextStyles.tabular)),
          Text(label, style: TextStyles.footnote.copyWith(color: Colors.white70)),
        ],
      );
}

/// How to get points, each linking to where you do it.
class _WaysToEarn extends StatelessWidget {
  const _WaysToEarn();

  @override
  Widget build(BuildContext context) {
    void toReport(ReportsFeed feed) {
      context.read<ReportsController>().show(feed);
      context.read<AppNav>().go(AppNav.report);
    }

    return Group(
      dividerIndent: 64,
      children: [
        _EarnRow(
          icon: CupertinoIcons.exclamationmark_triangle_fill,
          title: 'Report an obstacle',
          detail: 'As soon as you send it',
          points: 10,
          onTap: () => toReport(ReportsFeed.mine),
        ),
        _EarnRow(
          icon: CupertinoIcons.checkmark_circle_fill,
          title: 'Your report is confirmed',
          detail: 'When other users say it is still there',
          points: 40,
          onTap: () => toReport(ReportsFeed.mine),
        ),
        _EarnRow(
          icon: CupertinoIcons.hand_thumbsup,
          title: "Check others' reports",
          detail: 'Tell people if a barrier is still there',
          points: 5,
          onTap: () => toReport(ReportsFeed.community),
        ),
      ],
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.points,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        semanticLabel: '$title, $points points. $detail',
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Palette.mint, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: Palette.moss),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyles.body),
                    Text(detail, style: TextStyles.footnote),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+$points',
                style: TextStyles.headline.copyWith(color: Palette.moss, fontFeatures: TextStyles.tabular),
              ),
            ],
          ),
        ),
      );
}

class _PartnerIcon extends StatelessWidget {
  const _PartnerIcon(this.partner);

  final RewardPartner partner;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Palette.mint, borderRadius: BorderRadius.circular(10)),
        child: Icon(partnerIcon(partner), size: 21, color: Palette.moss),
      );
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.reward, required this.affordable, required this.onTap});

  final Reward reward;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: affordable ? onTap : null,
      semanticLabel: affordable
          ? '${reward.partnerName} ${reward.title}, ${reward.cost} points'
          : '${reward.partnerName} ${reward.title}, ${reward.cost} points, not enough points yet',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _PartnerIcon(reward.partner),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.title, style: TextStyles.body),
                  Text('${reward.partnerName}, demo partner', style: TextStyles.footnote),
                  const SizedBox(height: 2),
                  Text(reward.description, style: TextStyles.footnote),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: affordable ? Palette.moss : Palette.field,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text(
                '${reward.cost} pts',
                style: TextStyles.subhead.copyWith(
                  fontWeight: FontWeight.w600,
                  color: affordable ? Colors.white : Palette.tertiary,
                  fontFeatures: TextStyles.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
