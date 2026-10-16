import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// iOS-style tap target: dims while pressed and gives a light haptic tick.
/// Replaces Material ink ripples, which look out of place on iPhone.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.selected,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool? selected;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedOpacity(
          opacity: _down ? 0.55 : 1,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// An iOS inset-grouped section: rows on one rounded surface, split by hairlines.
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.color = Palette.surface, this.dividerIndent = 16});

  final List<Widget> children;
  final Color color;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: dividerIndent),
          child: const Divider(height: 0.5, thickness: 0.5, color: Palette.hairline),
        ));
      }
      rows.add(children[i]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.group),
      child: ColoredBox(
        color: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    );
  }
}

/// Section title that sits above a [Group], in sentence case.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: TextStyles.headline)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Explanatory text under a group, like an iOS section footer.
class SectionFooter extends StatelessWidget {
  const SectionFooter(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(text, style: TextStyles.footnote),
      );
}

/// Full-width primary action. Shows a spinner while [loading].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.tone = ButtonTone.filled,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final filled = tone == ButtonTone.filled;
    final bg = filled ? (enabled || loading ? Palette.moss : Palette.field) : Colors.transparent;
    final fg = filled ? (enabled || loading ? Colors.white : Palette.tertiary) : Palette.moss;

    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.control)),
        alignment: Alignment.center,
        child: loading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyles.headline.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum ButtonTone { filled, plain }

/// The user's points, shown wherever the balance matters.
class PointsPill extends StatelessWidget {
  const PointsPill(this.points, {super.key, this.onDark = false});

  final int points;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$points points',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.12) : Palette.mint,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.star_circle_fill, size: 17, color: Palette.moss),
            const SizedBox(width: 5),
            Text(
              '$points',
              style: TextStyles.subhead.copyWith(
                fontWeight: FontWeight.w700,
                color: onDark ? Colors.white : Palette.moss,
                fontFeatures: TextStyles.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mapOKU logo tile.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Image.asset('assets/images/mapoku_logo.png', excludeFromSemantics: true, filterQuality: FilterQuality.high),
      );
}

/// Mark plus the "mapOKU" name, used in the header on every tab.
class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'mapOKU',
        excludeSemantics: true,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoMark(size: 36),
            SizedBox(width: 8),
            Text('mapOKU', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Palette.ink, letterSpacing: -0.3)),
          ],
        ),
      );
}

/// Large two-or-three way switcher, roomier than the stock iOS segmented
/// control so labels and counts never get cut off.
class SegmentTabs<T> extends StatelessWidget {
  const SegmentTabs({super.key, required this.value, required this.items, required this.onChanged});

  final T value;

  /// value → (label, optional count)
  final Map<T, (String, int?)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Palette.field, borderRadius: BorderRadius.circular(Radii.control + 2)),
      child: Row(
        children: [
          for (final e in items.entries)
            Expanded(
              child: Pressable(
                selected: e.key == value,
                semanticLabel: e.value.$2 == null ? e.value.$1 : '${e.value.$1}, ${e.value.$2}',
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.key == value ? Palette.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.control - 2),
                    boxShadow: e.key == value
                        ? const [BoxShadow(color: Color(0x1A1E2B22), blurRadius: 6, offset: Offset(0, 1))]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          e.value.$1,
                          textAlign: TextAlign.center,
                          style: TextStyles.callout.copyWith(
                            fontWeight: e.key == value ? FontWeight.w700 : FontWeight.w500,
                            color: e.key == value ? Palette.ink : Palette.secondary,
                          ),
                        ),
                      ),
                      if (e.value.$2 != null && e.value.$2! > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: e.key == value ? Palette.moss : Palette.hairline,
                            borderRadius: BorderRadius.circular(Radii.chip),
                          ),
                          child: Text(
                            '${e.value.$2}',
                            textAlign: TextAlign.center,
                            style: TextStyles.caption.copyWith(
                              color: e.key == value ? Colors.white : Palette.ink,
                              fontWeight: FontWeight.w700,
                              fontFeatures: TextStyles.tabular,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "Suggested".
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Palette.moss, this.background = Palette.mint});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Radii.chip)),
        child: Text(text, style: TextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}
