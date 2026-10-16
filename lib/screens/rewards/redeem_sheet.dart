import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

IconData partnerIcon(RewardPartner p) => switch (p) {
      RewardPartner.grab => CupertinoIcons.car_fill,
      RewardPartner.rapidKL => CupertinoIcons.tram_fill,
      RewardPartner.touchNGo => CupertinoIcons.creditcard_fill,
    };

Future<void> showRedeemSheet(BuildContext context, Reward reward) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _RedeemSheet(reward: reward),
  );
}

/// Shows a voucher the user already redeemed, with its code.
Future<void> showVoucherSheet(BuildContext context, Voucher v) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${v.reward.partnerName} ${v.reward.title}', style: TextStyles.title2),
          const SizedBox(height: 4),
          Text(
            'Redeemed ${shortDate(v.redeemedAt)}. Use it by ${shortDate(v.expiresAt)}.',
            style: TextStyles.subhead,
          ),
          const SizedBox(height: 20),
          VoucherCodeBox(code: v.code),
          const SizedBox(height: 10),
          Text(
            'Enter this code in the ${v.reward.partnerName} app.',
            textAlign: TextAlign.center,
            style: TextStyles.footnote,
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  );
}

enum _Step { confirm, redeeming, done }

class _RedeemSheet extends StatefulWidget {
  const _RedeemSheet({required this.reward});

  final Reward reward;

  @override
  State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> {
  _Step _step = _Step.confirm;
  RedeemResult? _result;
  String? _error;

  Future<void> _redeem() async {
    setState(() {
      _step = _Step.redeeming;
      _error = null;
    });
    try {
      final r = await context.read<AppState>().redeem(widget.reward);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _result = r;
        _step = _Step.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = _Step.confirm;
        _error = "Couldn't redeem. Your points weren't used. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: AnimatedSize(
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: _step == _Step.done ? _done() : _confirm(),
      ),
    );
  }

  Widget _confirm() {
    final r = widget.reward;
    final points = context.select<AppState, int>((s) => s.points);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Palette.mint, borderRadius: BorderRadius.circular(12)),
              child: Icon(partnerIcon(r.partner), color: Palette.moss),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title, style: TextStyles.title3),
                  Text('${r.partnerName}, demo partner', style: TextStyles.subhead),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(r.description, style: TextStyles.callout.copyWith(color: Palette.secondary)),
        const SizedBox(height: 20),
        Group(
          color: Palette.field,
          children: [
            _Line('Cost', '${r.cost} pts'),
            _Line('Your points', '$points pts'),
            _Line('After redeeming', '${points - r.cost} pts', emphasis: true),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyles.footnote.copyWith(color: Palette.amberText)),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Redeem for ${r.cost} points',
          loading: _step == _Step.redeeming,
          onPressed: _redeem,
        ),
        const SizedBox(height: 4),
        PrimaryButton(
          label: 'Cancel',
          tone: ButtonTone.plain,
          onPressed: _step == _Step.redeeming ? null : () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _done() {
    final res = _result!;
    final r = widget.reward;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(CupertinoIcons.checkmark_circle_fill, size: 56, color: Palette.moss),
        const SizedBox(height: 12),
        const Text('Redeemed', textAlign: TextAlign.center, style: TextStyles.title2),
        const SizedBox(height: 6),
        Text(
          'Enter this code in the ${r.partnerName} app to claim your ${r.title}. '
          "It's also saved under My vouchers.",
          textAlign: TextAlign.center,
          style: TextStyles.subhead,
        ),
        const SizedBox(height: 20),
        VoucherCodeBox(code: res.voucher.code),
        const SizedBox(height: 10),
        Text('${res.pointsLeft} points left', textAlign: TextAlign.center, style: TextStyles.footnote),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
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
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
      decoration: BoxDecoration(
        color: Palette.mint,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Palette.moss, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              widget.code,
              style: TextStyles.title3.copyWith(letterSpacing: 2, fontFeatures: TextStyles.tabular),
            ),
          ),
          Pressable(
            onTap: _copy,
            semanticLabel: _copied ? 'Copied' : 'Copy code',
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_copied ? CupertinoIcons.checkmark_alt : CupertinoIcons.doc_on_doc, size: 18, color: Palette.moss),
                  const SizedBox(width: 6),
                  Text(_copied ? 'Copied' : 'Copy', style: TextStyles.headline.copyWith(color: Palette.moss)),
                ],
              ),
            ),
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
            Expanded(child: Text(label, style: TextStyles.body.copyWith(color: Palette.secondary))),
            Text(
              value,
              style: TextStyles.body.copyWith(
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                color: emphasis ? Palette.moss : Palette.ink,
                fontFeatures: TextStyles.tabular,
              ),
            ),
          ],
        ),
      );
}
