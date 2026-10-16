import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/demo_data.dart';
import '../models/reward.dart';
import '../state/app_scope.dart';
import '../widgets/redeem_reward_sheet.dart';
import '../widgets/reward_card.dart';

/// Points wallet, reward catalogue and redemption history.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

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
            'Turn your contributions into real perks.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _PointsHero(points: state.points, redemptions: state.redemptions.length),
          const SizedBox(height: 14),
          const _HowPointsWork(),
          const SizedBox(height: 20),
          Text('Redeem your points', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final reward in DemoData.rewards) ...[
            RewardCard(
              reward: reward,
              points: state.points,
              onRedeem: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => RedeemRewardSheet(reward: reward),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.redemptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Your vouchers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final redemption in state.redemptions)
              _HistoryTile(redemption: redemption),
          ],
        ],
      ),
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({required this.points, required this.redemptions});

  final int points;
  final int redemptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Points balance',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('🪙', style: TextStyle(fontSize: 26)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                redemptions == 0
                    ? 'From community reports and confirmations'
                    : '$redemptions reward${redemptions == 1 ? '' : 's'} redeemed',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowPointsWork extends StatelessWidget {
  const _HowPointsWork();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How points work', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          const _PointRow(icon: '🚨', text: 'Report an obstacle — earn +10 pts'),
          const SizedBox(height: 6),
          const _PointRow(icon: '✅', text: 'A report gets confirmed — earn +40 pts'),
          const SizedBox(height: 6),
          const _PointRow(icon: '👍', text: 'Confirm others — earn +2 pts'),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.redemption});

  final Redemption redemption;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(redemption.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${redemption.code} · ${DateFormat('d MMM, h:mm a').format(redemption.redeemedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '-${redemption.cost} 🪙',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}