import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/sime_darby_hub.dart';

/// Soft shadow used by every floating control over the full-screen map.
const List<BoxShadow> _floatingShadow = <BoxShadow>[
  BoxShadow(color: Color(0x3D000000), blurRadius: 14, offset: Offset(0, 5)),
];

/// Floating Sime Darby Property location pills, Google-Maps style.
///
/// Renders over the top of the full-screen map: an optional brand banner plus
/// a scrollable strip of hub pills. The banner collapses to a small toggle so
/// the map stays completely unobstructed.
class SimeDarbySelector extends StatelessWidget {
  const SimeDarbySelector({
    super.key,
    required this.hubs,
    required this.selectedIndex,
    required this.onChanged,
    required this.bannerVisible,
    required this.onToggleBanner,
  });

  final List<SimeDarbyHub> hubs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool bannerVisible;
  final VoidCallback onToggleBanner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (bannerVisible) ...<Widget>[
          _BrandBanner(onHide: onToggleBanner),
          const SizedBox(height: 8),
        ],
        Row(
          children: <Widget>[
            if (!bannerVisible) ...<Widget>[
              _BannerToggle(onShow: onToggleBanner),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _PillStrip(
                hubs: hubs,
                selectedIndex: selectedIndex,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Collapsible "SIME DARBY PROPERTY" brand banner.
class _BrandBanner extends StatelessWidget {
  const _BrandBanner({required this.onHide});

  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.sdpCharcoal.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _floatingShadow,
      ),
      child: Row(
        children: <Widget>[
          Container(width: 4, height: 26, color: AppColors.sdpRed),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'SIME DARBY PROPERTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '3D Pedestrian & OKU Wayfinding Demo',
                  style: TextStyle(
                    color: AppColors.sdpGreyMid,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _RoundIconButton(
            icon: Icons.keyboard_arrow_up,
            tooltip: 'Hide Sime Darby banner',
            onTap: onHide,
          ),
        ],
      ),
    );
  }
}

/// Small floating button that brings the brand banner back.
class _BannerToggle extends StatelessWidget {
  const _BannerToggle({required this.onShow});

  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show Sime Darby banner',
      child: Material(
        color: AppColors.sdpCharcoal.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        elevation: 3,
        shadowColor: const Color(0x66000000),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onShow,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(11, 11, 12, 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.sdpRed, shape: BoxShape.circle),
                  ),
                ),
                SizedBox(width: 7),
                Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable row of hub pills.
class _PillStrip extends StatelessWidget {
  const _PillStrip({
    required this.hubs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<SimeDarbyHub> hubs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: hubs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hub = hubs[index];
          return _HubPill(
            label: hub.name,
            selected: index == selectedIndex,
            onTap: () => onChanged(index),
          );
        },
      ),
    );
  }
}

/// A single floating hub pill.
class _HubPill extends StatelessWidget {
  const _HubPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? Colors.white
        : AppColors.sdpCharcoal.withValues(alpha: 0.9);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      shadowColor: const Color(0x59000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.sdpRed : Colors.white.withValues(alpha: 0.22),
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.sdpRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.sdpCharcoal : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent round icon button used inside the floating banner.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}