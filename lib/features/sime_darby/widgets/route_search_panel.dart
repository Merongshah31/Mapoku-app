import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Accessibility need chosen in the trip planner.
///
/// This is the single control that decides the routing mode: every option
/// except [standard] uses the OKU / wheelchair (step-free) routing.
enum AccessibilityNeed {
  wheelchair('Wheelchair', Icons.accessible),
  crutchesElderly('Crutches / elderly', Icons.elderly),
  visualTactile('Visual / tactile', Icons.visibility),
  standard('Standard', Icons.directions_walk);

  const AccessibilityNeed(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isAccessible => this != AccessibilityNeed.standard;
}

/// Trip planner card: a connected From → To route plus the accessibility need.
class RouteSearchPanel extends StatelessWidget {
  const RouteSearchPanel({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.need,
    required this.onNeedChanged,
    required this.onVoiceTap,
  });

  final String fromLabel;
  final String toLabel;
  final AccessibilityNeed need;
  final ValueChanged<AccessibilityNeed> onNeedChanged;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _RouteEndpoints(
          fromLabel: fromLabel,
          toLabel: toLabel,
          onVoiceTap: onVoiceTap,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('Who is travelling?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final option in AccessibilityNeed.values)
              _NeedChip(
                need: option,
                selected: option == need,
                onTap: () => onNeedChanged(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Google-Maps-style connected From / To rows.
class _RouteEndpoints extends StatelessWidget {
  const _RouteEndpoints({
    required this.fromLabel,
    required this.toLabel,
    required this.onVoiceTap,
  });

  final String fromLabel;
  final String toLabel;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          _EndpointRow(
            label: 'From',
            value: fromLabel,
            marker: const _Dot(color: AppColors.primary),
          ),
          const Divider(height: 1, indent: 52),
          _EndpointRow(
            label: 'To',
            value: toLabel,
            marker: const Icon(
              Icons.location_on,
              size: 18,
              color: AppColors.accent,
            ),
            trailing: Tooltip(
              message: 'Say your destination',
              child: IconButton(
                onPressed: onVoiceTap,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(
                  Icons.mic_none,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3.5),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.label,
    required this.value,
    required this.marker,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget marker;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: <Widget>[
          SizedBox(width: 52, child: Center(child: marker)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing ?? const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _NeedChip extends StatelessWidget {
  const _NeedChip({
    required this.need,
    required this.selected,
    required this.onTap,
  });

  final AccessibilityNeed need;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: need.label,
      child: Material(
        color: selected ? AppColors.primary : AppColors.field,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(need.icon, size: 17, color: foreground),
                const SizedBox(width: 6),
                Text(
                  need.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
