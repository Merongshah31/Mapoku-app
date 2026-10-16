import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/reward.dart';
import '../state/app_scope.dart';

/// Two-step redemption flow: confirm, then show the voucher code.
class RedeemRewardSheet extends StatefulWidget {
  const RedeemRewardSheet({super.key, required this.reward});

  final Reward reward;

  @override
  State<RedeemRewardSheet> createState() => _RedeemRewardSheetState();
}

class _RedeemRewardSheetState extends State<RedeemRewardSheet> {
  Redemption? _redemption;
  bool _copied = false;

  void _confirm() {
    final redemption = AppScope.of(context).redeem(widget.reward);
    if (redemption == null) return;
    setState(() => _redemption = redemption);
  }

  Future<void> _copy() async {
    final code = _redemption?.code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final redemption = _redemption;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: redemption == null
          ? _ConfirmStep(
              reward: widget.reward,
              points: AppScope.of(context).points,
              onConfirm: _confirm,
              onCancel: () => Navigator.of(context).pop(),
            )
          : _SuccessStep(
              redemption: redemption,
              reward: widget.reward,
              copied: _copied,
              onCopy: _copy,
              onDone: () => Navigator.of(context).pop(),
            ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.reward,
    required this.points,
    required this.onConfirm,
    required this.onCancel,
  });

  final Reward reward;
  final int points;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(reward.colorValue).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(reward.emoji, style: const TextStyle(fontSize: 34)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text('Redeem ${reward.label}?', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('${reward.brand} · simulated partner', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            children: [
              _row('Cost', '${reward.cost} 🪙'),
              const SizedBox(height: 10),
              _row('Your balance', '$points 🪙'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _row('Balance after', '${points - reward.cost} 🪙', highlight: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onConfirm, child: const Text('Confirm redemption')),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({
    required this.redemption,
    required this.reward,
    required this.copied,
    required this.onCopy,
    required this.onDone,
  });

  final Redemption redemption;
  final Reward reward;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 34, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 14),
        Center(child: Text('Redeemed!', style: theme.textTheme.headlineSmall)),
        const SizedBox(height: 6),
        Text(
          'Your ${reward.label} is ready. Show this code to claim it.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  redemption.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              TextButton(onPressed: onCopy, child: Text(copied ? 'Copied!' : 'Copy')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}