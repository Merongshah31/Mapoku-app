import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/constants/app_colors.dart';
import '../models/sime_darby_hub.dart';

/// Frosted Sime Darby Property location chips floating over the 3D map.
///
/// A single horizontally scrollable strip; the selected chip is filled with the
/// brand green so the active hub is obvious at a glance.
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
    return PointerInterceptor(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _BrandBanner(expanded: bannerVisible, onToggle: onToggleBanner),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: hubs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _HubChip(
                hub: hubs[index],
                selected: index == selectedIndex,
                onTap: () => onChanged(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "SIME DARBY PROPERTY" brand banner; collapses to a small chip.
class _BrandBanner extends StatelessWidget {
  const _BrandBanner({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: AppColors.surface.withValues(alpha: 0.9),
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: expanded ? 26 : 18,
                      color: AppColors.sdpRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            'SIME DARBY PROPERTY',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (expanded)
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Text(
                                '3D Pedestrian & OKU Wayfinding Demo',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubChip extends StatelessWidget {
  const _HubChip({
    required this.hub,
    required this.selected,
    required this.onTap,
  });

  final SimeDarbyHub hub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${hub.name}, ${hub.subtitle}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: selected
                ? AppColors.primary
                : AppColors.surface.withValues(alpha: 0.9),
            child: InkWell(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                child: Text(
                  hub.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
