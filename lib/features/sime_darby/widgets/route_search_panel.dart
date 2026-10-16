import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Accessibility need selected in the mapOKU search card.
///
/// Kept in sync with the "Route Mode" toggle in the Quick Demo panel:
/// every option except [standard] uses the OKU / wheelchair routing.
enum AccessibilityNeed {
  wheelchair('Wheelchair', Icons.accessible),
  crutchesElderly('Crutches / Elderly', Icons.elderly),
  visualTactile('Visual Impairment / Tactile', Icons.visibility),
  standard('Standard Pedestrian', Icons.directions_walk);

  const AccessibilityNeed(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isAccessible => this != AccessibilityNeed.standard;
}

/// mapOKU trip search card: From (Pin A) and To (Pin B) plus the
/// accessibility need that drives the routing mode.
class RouteSearchPanel extends StatefulWidget {
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
  State<RouteSearchPanel> createState() => _RouteSearchPanelState();
}

class _RouteSearchPanelState extends State<RouteSearchPanel> {
  late final TextEditingController _from = TextEditingController(text: widget.fromLabel);
  late final TextEditingController _to = TextEditingController(text: widget.toLabel);

  @override
  void didUpdateWidget(covariant RouteSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromLabel != widget.fromLabel) _from.text = widget.fromLabel;
    if (oldWidget.toLabel != widget.toLabel) _to.text = widget.toLabel;
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sdpCharcoal,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.directions_walk, size: 18, color: AppColors.routeAccessible),
              const SizedBox(width: 8),
              Text(
                'PLAN AN ACCESSIBLE TRIP',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SearchField(
            label: 'FROM',
            controller: _from,
            leading: Icons.mic,
            leadingTooltip: 'Voice input for the start point',
            onLeadingTap: widget.onVoiceTap,
            accent: AppColors.forest,
          ),
          const SizedBox(height: 10),
          _SearchField(
            label: 'TO',
            controller: _to,
            leading: Icons.search,
            leadingTooltip: 'Search the destination',
            onLeadingTap: null,
            trailing: Icons.mic,
            trailingTooltip: 'Voice input for the destination',
            onTrailingTap: widget.onVoiceTap,
            accent: AppColors.accent,
          ),
          const SizedBox(height: 14),
          const Text(
            'ACCESSIBILITY NEED',
            style: TextStyle(
              color: AppColors.sdpGreyMid,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          _NeedDropdown(value: widget.need, onChanged: widget.onNeedChanged),
        ],
      ),
    );
  }
}

/// A read-only mapOKU search box showing the active Pin address, with the
/// microphone / magnifier affordances from the original app.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.label,
    required this.controller,
    required this.leading,
    required this.accent,
    required this.onLeadingTap,
    this.leadingTooltip = 'Voice input',
    this.trailing,
    this.onTrailingTap,
    this.trailingTooltip = 'Voice input',
  });

  final String label;
  final TextEditingController controller;
  final IconData leading;
  final Color accent;
  final VoidCallback? onLeadingTap;
  final String leadingTooltip;
  final IconData? trailing;
  final VoidCallback? onTrailingTap;
  final String trailingTooltip;

  @override
  Widget build(BuildContext context) {
    final trailingIcon = trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.sdpGreyMid,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _IconAction(
              icon: leading,
              tooltip: leadingTooltip,
              color: accent,
              onTap: onLeadingTap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Text(
                  controller.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (trailingIcon != null) ...<Widget>[
              const SizedBox(width: 8),
              _IconAction(
                icon: trailingIcon,
                tooltip: trailingTooltip,
                color: accent,
                onTap: onTrailingTap,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, size: 18, color: color == AppColors.forest ? Colors.white : color),
          ),
        ),
      ),
    );
  }
}

/// Fully controlled dropdown so it stays in sync with the Route Mode toggle.
class _NeedDropdown extends StatelessWidget {
  const _NeedDropdown({required this.value, required this.onChanged});

  final AccessibilityNeed value;
  final ValueChanged<AccessibilityNeed> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: DropdownButton<AccessibilityNeed>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.sdpCharcoalSoft,
        iconEnabledColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        items: <DropdownMenuItem<AccessibilityNeed>>[
          for (final need in AccessibilityNeed.values)
            DropdownMenuItem<AccessibilityNeed>(
              value: need,
              child: Row(
                children: <Widget>[
                  Icon(
                    need.icon,
                    size: 16,
                    color: need.isAccessible ? AppColors.routeAccessible : Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(need.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}