import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/reward.dart';

/// Wallet-style reward card. Shows the cost and a redeem action.
class RewardCard extends StatelessWidget {
  const RewardCard({
    super.key,
    required this.reward,
    required this.points,
    required this.onRedeem,
  });

  final Reward reward;
  final int points;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final affordable = reward.canAfford(points);
    final color = Color(reward.colorValue);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1E2B22), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(reward.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.brand.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.6),
                ),
                const SizedBox(height: 3),
                Text(reward.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  reward.tagline,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '${reward.cost} points',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RedeemButton(affordable: affordable, onRedeem: onRedeem),
        ],
      ),
    );
  }
}

class _RedeemButton extends StatelessWidget {
  const _RedeemButton({required this.affordable, required this.onRedeem});

  final bool affordable;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    if (!affordable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Locked',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textTertiary),
        ),
      );
    }

    return FilledButton(
      onPressed: onRedeem,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: const Text('Redeem'),
    );
  }
}