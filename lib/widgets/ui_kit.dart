import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Shared building blocks for the Rewards and Reports screens: grouped list
/// cards, section headings and the segmented switch.

const TextStyle kBodyStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
);

const TextStyle kFootnoteStyle = TextStyle(
  fontSize: 12.5,
  color: AppColors.textSecondary,
  height: 1.3,
);

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;

  /// Optional action on the right, e.g. an "Add" button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(4, trailing == null ? 24 : 16, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}

class SectionFooter extends StatelessWidget {
  const SectionFooter(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
    child: Text(text, style: kFootnoteStyle),
  );
}

/// Rounded card that stacks rows with inset hairline dividers.
class AppGroup extends StatelessWidget {
  const AppGroup({
    super.key,
    required this.children,
    this.dividerIndent = 16,
    this.color = AppColors.card,
    this.bordered = true,
  });

  final List<Widget> children;
  final double dividerIndent;
  final Color color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: bordered ? Border.all(color: AppColors.border) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: dividerIndent),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented switch. Each item is a label plus an optional count badge.
class SegmentTabs<T> extends StatelessWidget {
  const SegmentTabs({
    super.key,
    required this.value,
    required this.onChanged,
    required this.items,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, (String, int?)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          for (final entry in items.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: entry.key == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == value
                          ? AppColors.card
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusSm - 2,
                      ),
                      boxShadow: entry.key == value
                          ? const [
                              BoxShadow(
                                color: Color(0x141E2B22),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      entry.value.$2 == null || entry.value.$2 == 0
                          ? entry.value.$1
                          : '${entry.value.$1} (${entry.value.$2})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: entry.key == value
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
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
