import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_theme.dart';
import '../data/demo_data.dart';
import '../models/report.dart';
import '../models/reward.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/redeem_reward_sheet.dart';
import '../widgets/ui_kit.dart';

enum _View { rewards, vouchers }

/// Rewards tab: balance, ways to earn, rewards to redeem and your vouchers.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  _View _view = _View.rewards;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Rewards', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(
            'Status: Earning',
            style: kFootnoteStyle.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Turn your contributions into real perks.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _Balance(state: state),
          const SectionTitle('Ways to earn'),
          const _WaysToEarn(),
          const SizedBox(height: 24),
          SegmentTabs<_View>(
            value: _view,
            onChanged: (v) => setState(() => _view = v),
            items: {
              _View.rewards: ('Redeem', null),
              _View.vouchers: ('Vouchers', state.redemptions.length),
            },
          ),
          ...switch (_view) {
            _View.rewards => _rewards(context, state),
            _View.vouchers => _vouchers(context, state),
          },
        ],
      ),
    );
  }

  List<Widget> _rewards(BuildContext context, AppState state) => [
    const SizedBox(height: 16),
    AppGroup(
      dividerIndent: 68,
      children: [
        for (final reward in DemoData.rewards)
          _RewardRow(
            reward: reward,
            affordable: reward.canAfford(state.points),
            onTap: () => showRedeemSheet(context, reward),
          ),
      ],
    ),
    const SectionFooter(
      'Points unlock once other members confirm the obstacles you report, '
      'which keeps reports honest. Partners fund the rewards, so they '
      'cost you nothing.',
    ),
  ];

  List<Widget> _vouchers(BuildContext context, AppState state) {
    if (state.redemptions.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Icon(
          CupertinoIcons.gift,
          size: 40,
          color: AppColors.textTertiary,
        ),
        const SizedBox(height: 12),
        Text(
          'Rewards you redeem are saved here, so you can find the code later.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }
    return [
      const SizedBox(height: 16),
      AppGroup(
        dividerIndent: 68,
        children: [
          for (final redemption in state.redemptions)
            _VoucherRow(
              redemption: redemption,
              onTap: () => showVoucherSheet(context, redemption),
            ),
        ],
      ),
    ];
  }
}

// -----------------------------------------------------------------------------
// Balance
// -----------------------------------------------------------------------------

class _Balance extends StatelessWidget {
  const _Balance({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final points = state.points;
    final sorted = [...DemoData.rewards]
      ..sort((a, b) => a.cost.compareTo(b.cost));
    final goal = sorted.where((r) => r.cost > points).firstOrNull;
    final progress = goal == null ? 1.0 : (points / goal.cost).clamp(0.0, 1.0);
    final verified = state.myReports
        .where((r) => r.status == ReportStatus.verified)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your points',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Semantics(
            label: '$points points',
            excludeSemantics: true,
            child: Text(
              '$points',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
                fontFeatures: [FontFeature.tabularFigures()],
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
                : '${goal.cost - points} more for ${goal.brand} ${goal.label}',
            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 0.5, color: Color(0x33FFFFFF)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: state.myReports.length,
                  label: 'Reports sent',
                ),
              ),
              Expanded(
                child: _Stat(value: verified, label: 'Confirmed'),
              ),
              Expanded(
                child: _Stat(
                  value: state.redemptions.length,
                  label: 'Vouchers',
                ),
              ),
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
      Text(
        '$value',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ],
  );
}

// -----------------------------------------------------------------------------
// Ways to earn
// -----------------------------------------------------------------------------

class _WaysToEarn extends StatelessWidget {
  const _WaysToEarn();

  @override
  Widget build(BuildContext context) {
    return const AppGroup(
      dividerIndent: 64,
      children: [
        _EarnRow(
          icon: CupertinoIcons.exclamationmark_triangle_fill,
          title: 'Report an obstacle',
          detail: 'As soon as you send it',
          points: AppConfig.pointsPerReport,
        ),
        _EarnRow(
          icon: CupertinoIcons.checkmark_circle_fill,
          title: 'Your report is confirmed',
          detail: 'When other members say it is still there',
          points: AppConfig.pointsPerConfirmation,
        ),
        _EarnRow(
          icon: CupertinoIcons.hand_thumbsup,
          title: "Check others' reports",
          detail: 'Tell people if a barrier is still there',
          points: 2,
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
  });

  final IconData icon;
  final String title;
  final String detail;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title, $points points. $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconTile(
              size: 36,
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: kBodyStyle),
                  Text(detail, style: kFootnoteStyle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+$points',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reward + voucher rows
// -----------------------------------------------------------------------------

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.reward,
    required this.affordable,
    required this.onTap,
  });

  final Reward reward;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: affordable,
      label: affordable
          ? '${reward.brand} ${reward.label}, ${reward.cost} points'
          : '${reward.brand} ${reward.label}, ${reward.cost} points, not enough points yet',
      excludeSemantics: true,
      child: InkWell(
        onTap: affordable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _RewardIcon(reward),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reward.label, style: kBodyStyle),
                    Text(
                      '${reward.brand}, simulated partner',
                      style: kFootnoteStyle,
                    ),
                    if (reward.tagline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(reward.tagline, style: kFootnoteStyle),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: affordable ? AppColors.primary : AppColors.field,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${reward.cost} pts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: affordable ? Colors.white : AppColors.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.redemption, required this.onTap});

  final Redemption redemption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${redemption.brand} ${redemption.label}, code ${redemption.code}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _IconTile(
                size: 40,
                child: Icon(
                  _iconFor(redemption.rewardId),
                  size: 21,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(redemption.label, style: kBodyStyle),
                    Text(
                      '${redemption.brand} · ${DateFormat('d MMM, h:mm a').format(redemption.redeemedAt)}',
                      style: kFootnoteStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String rewardId) {
    for (final reward in DemoData.rewards) {
      if (reward.id == rewardId) return reward.icon;
    }
    return Icons.confirmation_number_outlined;
  }
}

class _RewardIcon extends StatelessWidget {
  const _RewardIcon(this.reward);

  final Reward reward;

  @override
  Widget build(BuildContext context) => _IconTile(
    size: 40,
    child: Icon(reward.icon, size: 21, color: AppColors.primary),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}
