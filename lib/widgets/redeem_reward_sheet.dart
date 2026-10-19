import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/reward.dart';
import '../state/app_scope.dart';

Future<void> showRedeemSheet(BuildContext context, Reward reward) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => RedeemRewardSheet(reward: reward),
  );
}

/// Shows a voucher the user already redeemed, with its code.
Future<void> showVoucherSheet(BuildContext context, Redemption redemption) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.paddingOf(ctx).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(redemption.label, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${redemption.brand} · redeemed '
            '${DateFormat('d MMM, h:mm a').format(redemption.redeemedAt)}',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          VoucherCodeBox(code: redemption.code),
          const SizedBox(height: 10),
          Text(
            'Enter this code in the ${redemption.brand} app.',
            textAlign: TextAlign.center,
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

/// Two-step redemption flow: confirm, then show the voucher code.
class RedeemRewardSheet extends StatefulWidget {
  const RedeemRewardSheet({super.key, required this.reward});

  final Reward reward;

  @override
  State<RedeemRewardSheet> createState() => _RedeemRewardSheetState();
}

class _RedeemRewardSheetState extends State<RedeemRewardSheet> {
  Redemption? _redemption;

  void _redeem() {
    final redemption = AppScope.of(context).redeem(widget.reward);
    if (redemption == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _redemption = redemption);
  }

  @override
  Widget build(BuildContext context) {
    final redemption = _redemption;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: AnimatedSize(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: redemption == null ? _confirm() : _done(redemption),
      ),
    );
  }

  Widget _confirm() {
    final reward = widget.reward;
    final theme = Theme.of(context);
    final points = AppScope.of(context).points;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(reward.icon, size: 24, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.label, style: theme.textTheme.titleMedium),
                  Text(
                    '${reward.brand}, simulated partner',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (reward.tagline.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            reward.tagline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            children: [
              _Line('Cost', '${reward.cost} pts'),
              const Divider(height: 1, indent: 16),
              _Line('Your points', '$points pts'),
              const Divider(height: 1, indent: 16),
              _Line(
                'After redeeming',
                '${points - reward.cost} pts',
                emphasis: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _redeem,
          child: Text('Redeem for ${reward.cost} points'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _done(Redemption redemption) {
    final reward = widget.reward;
    final theme = Theme.of(context);
    final points = AppScope.of(context).points;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(CupertinoIcons.checkmark_circle_fill, size: 56, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(
          'Redeemed',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Enter this code in the ${reward.brand} app to claim your ${reward.label}. '
          "It's also saved under Vouchers.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        VoucherCodeBox(code: redemption.code),
        const SizedBox(height: 10),
        Text(
          '$points points left',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Voucher code with a Copy button.
class VoucherCodeBox extends StatefulWidget {
  const VoucherCodeBox({super.key, required this.code});

  final String code;

  @override
  State<VoucherCodeBox> createState() => _VoucherCodeBoxState();
}

class _VoucherCodeBoxState extends State<VoucherCodeBox> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              widget.code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _copy,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: Icon(_copied ? CupertinoIcons.checkmark_alt : CupertinoIcons.doc_on_doc, size: 18),
            label: Text(_copied ? 'Copied' : 'Copy'),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
            color: emphasis ? AppColors.primary : AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
