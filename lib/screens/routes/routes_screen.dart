import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/routes_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/header.dart';
import 'route_map.dart';
import 'route_sheet.dart';

/// Routes tab: full-screen map with a draggable sheet over it.
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final _sheet = DraggableScrollableController();
  RoutesPhase? _lastPhase;

  static const _min = 0.14;
  static const _low = 0.34;
  static const _mid = 0.5;
  static const _max = 0.92;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  /// Raise the sheet when results arrive; lower it while navigating so the map shows.
  void _onPhase(RoutesPhase phase) {
    if (phase == _lastPhase) return;
    _lastPhase = phase;
    final target = switch (phase) {
      RoutesPhase.results => _mid,
      RoutesPhase.navigating => _low,
      _ => null,
    };
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheet.isAttached) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      _sheet.animateTo(
        target,
        duration: reduceMotion ? const Duration(milliseconds: 1) : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final phase = context.select<RoutesController, RoutesPhase>((c) => c.phase);
    _onPhase(phase);

    final media = MediaQuery.of(context);
    final showTownships = phase != RoutesPhase.navigating;
    // Header (52) + gap, plus the township row when it's showing.
    final topBarBottom = media.padding.top + 64 + (showTownships ? 54 : 0);

    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            Positioned.fill(
              child: RouteMap(topInset: topBarBottom, bottomInset: box.maxHeight * _mid),
            ),
            Positioned(left: 12, right: 12, top: media.padding.top + 8, child: const _TopBar()),
            if (showTownships)
              Positioned(left: 0, right: 0, top: media.padding.top + 66, child: const _TownshipBar()),
            Positioned(
              right: 16,
              top: topBarBottom + 4,
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyles.caption.copyWith(color: Palette.secondary, fontSize: 10),
              ),
            ),
            DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: _mid,
              minChildSize: _min,
              maxChildSize: _max,
              snap: true,
              snapSizes: const [_low, _mid],
              builder: (context, scroll) => DecoratedBox(
                decoration: const BoxDecoration(
                  color: Palette.page,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
                  boxShadow: [BoxShadow(color: Color(0x261E2B22), blurRadius: 18, offset: Offset(0, -2))],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
                  child: RouteSheetContent(
                    scrollController: scroll,
                    bottomPadding: media.padding.bottom + 24,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Floating header over the map: brand, points (opens Rewards), profile.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.group),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 10, right: 8),
          color: Palette.surface.withValues(alpha: 0.86),
          child: const Row(
            children: [
              Brand(),
              Spacer(),
              HeaderActions(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switches between the Sime Darby Property townships on the map.
class _TownshipBar extends StatelessWidget {
  const _TownshipBar();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoutesController>();
    if (c.townships.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final t in c.townships) ...[
            _TownshipChip(
              township: t,
              selected: c.township?.id == t.id,
              onTap: () => c.selectTownship(t),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TownshipChip extends StatelessWidget {
  const _TownshipChip({required this.township, required this.selected, required this.onTap});

  final Township township;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      selected: selected,
      semanticLabel: '${township.name}, ${township.location}',
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.chip),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            color: selected ? Palette.moss : Palette.surface.withValues(alpha: 0.9),
            child: Text(
              township.name,
              style: TextStyles.subhead.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
