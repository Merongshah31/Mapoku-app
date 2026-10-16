import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/sime_darby/data/sime_darby_demo_data.dart';
import '../features/sime_darby/models/sime_darby_hub.dart';
import '../features/sime_darby/services/accessible_pathfinder.dart';
import '../features/sime_darby/widgets/quick_demo_panel.dart';
import '../features/sime_darby/widgets/route_metrics_card.dart';
import '../features/sime_darby/widgets/route_search_panel.dart';
import '../features/sime_darby/widgets/sime_darby_map.dart';
import '../features/sime_darby/widgets/sime_darby_selector.dart';

/// Google-Maps-style full-screen 3D wayfinding demo for Sime Darby Property.
///
/// The MapLibre 3D street map fills the whole viewport edge to edge, and every
/// control floats above it: Sime Darby hub pills at the top, a collapsible
/// black "Plan an accessible trip" bottom sheet, a route legend and a
/// re-centre button. Nothing re-lays-out the map, so it can never stretch or
/// leave blank space when the cards open and close.
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  static const AccessiblePathfinder _pathfinder = AccessiblePathfinder();

  /// Visible sliver of the sheet when minimised: drag handle + title row.
  static const double _collapsedBarHeight = 52;

  static const Duration _slide = Duration(milliseconds: 300);
  static const double _gap = 12;

  int _hubIndex = 0;
  AccessibilityNeed _need = AccessibilityNeed.wheelchair;
  bool _obstacleActive = false;
  bool _sheetOpen = true;
  bool _bannerVisible = true;

  bool get _accessibilityMode => _need.isAccessible;

  SimeDarbyHub get _hub => SimeDarbyDemoData.hubs[_hubIndex];

  PathResult _path({required bool accessible, required bool obstacle}) {
    return _pathfinder.findPath(
          hub: _hub,
          accessibleOnly: accessible,
          obstacleActive: obstacle,
        ) ??
        const PathResult(
          nodes: <HubNode>[],
          polyline: <LatLng>[],
          distanceMeters: 0,
          coveredMeters: 0,
          hasStairs: false,
        );
  }

  String _signature(PathResult result) =>
      result.nodes.map((node) => node.id).join('>');

  void _onHubChanged(int index) {
    if (index == _hubIndex) return;
    setState(() {
      _hubIndex = index;
      _obstacleActive = false;
    });
  }

  /// Keeps the search-card dropdown and the Route Mode toggle in sync.
  void _onModeChanged(bool accessible) {
    setState(() {
      _need = accessible ? AccessibilityNeed.wheelchair : AccessibilityNeed.standard;
    });
  }

  void _toggleSheet() => setState(() => _sheetOpen = !_sheetOpen);

  /// Called by the map when the user pans / zooms it themselves.
  void _collapseSheet() {
    if (!_sheetOpen) return;
    setState(() => _sheetOpen = false);
  }

  void _toggleObstacle() {
    setState(() => _obstacleActive = !_obstacleActive);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _obstacleActive
                ? 'Construction simulated · ${_hub.simulationLabel}. Route re-calculated.'
                : 'Obstacle cleared · original walkway restored.',
          ),
        ),
      );
  }

  void _reset() {
    setState(() {
      _need = AccessibilityNeed.wheelchair;
      _obstacleActive = false;
    });
  }

  void _onVoiceTap() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Voice search uses the mapOKU /api/v1/voice/transcribe endpoint — '
            'microphone capture is not wired in this build.',
          ),
        ),
      );
  }

  void _showNodeInfo(HubNode node) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${node.icon}  ${node.label}',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(_hub.subtitle, style: Theme.of(sheetContext).textTheme.bodySmall),
            const SizedBox(height: 16),
            _NodeFact(
              icon: node.stepFree ? Icons.check_circle : Icons.warning_amber_rounded,
              label: node.stepFree
                  ? 'Step-free waypoint'
                  : 'Stairs present — not OKU accessible',
              color: node.stepFree ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(height: 8),
            _NodeFact(
              icon: node.covered ? Icons.umbrella : Icons.wb_sunny_outlined,
              label: node.covered ? 'Covered / weather-protected' : 'Open air walkway',
              color: node.covered ? AppColors.primary : AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = _hub;
    final active = _path(accessible: _accessibilityMode, obstacle: _obstacleActive);
    final base = _path(accessible: _accessibilityMode, obstacle: false);
    final alternate = _path(accessible: !_accessibilityMode, obstacle: _obstacleActive);
    final rerouted = _obstacleActive && _signature(base) != _signature(active);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The sheet keeps its size and only translates, so the map behind it
        // never has to re-layout.
        final sheetHeight = math.min(constraints.maxHeight * 0.76, 620.0);
        final sheetOffset = _sheetOpen ? 0.0 : -(sheetHeight - _collapsedBarHeight);
        final controlsBottom = _collapsedBarHeight + _gap;
        final sheetMaxWidth = math.min(constraints.maxWidth, 560.0);

        return Stack(
          children: <Widget>[
            // 1. Edge-to-edge full-screen 3D map.
            Positioned.fill(
              child: SimeDarbyMap(
                hub: hub,
                activeRoute: active,
                alternateRoute: alternate,
                accessibilityMode: _accessibilityMode,
                obstacleActive: _obstacleActive,
                onNodeTap: _showNodeInfo,
                onUserInteracted: _collapseSheet,
                bottomInset: controlsBottom,
                showMapControls: !_sheetOpen,
              ),
            ),

            // 2. Floating Sime Darby hub pills over the top of the map.
            Positioned(
              top: _gap,
              left: _gap,
              right: _gap,
              child: SafeArea(
                bottom: false,
                child: SimeDarbySelector(
                  hubs: SimeDarbyDemoData.hubs,
                  selectedIndex: _hubIndex,
                  onChanged: _onHubChanged,
                  bannerVisible: _bannerVisible,
                  onToggleBanner: () =>
                      setState(() => _bannerVisible = !_bannerVisible),
                ),
              ),
            ),

            // 3. Legend floats clear of the minimised bar; hidden while the
            //    sheet is open so it is never buried under it.
            AnimatedPositioned(
              duration: _slide,
              curve: Curves.easeOutCubic,
              left: _gap,
              bottom: controlsBottom,
              child: AnimatedOpacity(
                duration: _slide,
                opacity: _sheetOpen ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _sheetOpen,
                  child: const _MapLegend(),
                ),
              ),
            ),

            // 4. Collapsible black bottom sheet.
            AnimatedPositioned(
              duration: _slide,
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: sheetOffset,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: sheetMaxWidth),
                  child: SizedBox(
                    height: sheetHeight,
                    child: _TripBottomSheet(
                      hub: hub,
                      isOpen: _sheetOpen,
                      onToggle: _toggleSheet,
                      need: _need,
                      onNeedChanged: (need) => setState(() => _need = need),
                      onVoiceTap: _onVoiceTap,
                      accessibilityMode: _accessibilityMode,
                      onModeChanged: _onModeChanged,
                      obstacleActive: _obstacleActive,
                      onToggleObstacle: _toggleObstacle,
                      onReset: _reset,
                      result: active,
                      rerouted: rerouted,
                      activeNodes: active.nodes,
                    ),
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

/// The floating black "PLAN AN ACCESSIBLE TRIP" bottom sheet.
class _TripBottomSheet extends StatelessWidget {
  const _TripBottomSheet({
    required this.hub,
    required this.isOpen,
    required this.onToggle,
    required this.need,
    required this.onNeedChanged,
    required this.onVoiceTap,
    required this.accessibilityMode,
    required this.onModeChanged,
    required this.obstacleActive,
    required this.onToggleObstacle,
    required this.onReset,
    required this.result,
    required this.rerouted,
    required this.activeNodes,
  });

  final SimeDarbyHub hub;
  final bool isOpen;
  final VoidCallback onToggle;
  final AccessibilityNeed need;
  final ValueChanged<AccessibilityNeed> onNeedChanged;
  final VoidCallback onVoiceTap;
  final bool accessibilityMode;
  final ValueChanged<bool> onModeChanged;
  final bool obstacleActive;
  final VoidCallback onToggleObstacle;
  final VoidCallback onReset;
  final PathResult result;
  final bool rerouted;
  final List<HubNode> activeNodes;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.sdpCharcoal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        children: <Widget>[
          _SheetHeader(hub: hub, isOpen: isOpen, onToggle: onToggle),
          Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.12)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  RouteSearchPanel(
                    fromLabel: hub.pinALabel,
                    toLabel: hub.pinBLabel,
                    need: need,
                    onNeedChanged: onNeedChanged,
                    onVoiceTap: onVoiceTap,
                  ),
                  const SizedBox(height: 12),
                  QuickDemoPanel(
                    accessibilityMode: accessibilityMode,
                    onModeChanged: onModeChanged,
                    obstacleActive: obstacleActive,
                    onToggleObstacle: onToggleObstacle,
                    onReset: onReset,
                  ),
                  const SizedBox(height: 12),
                  RouteMetricsCard(
                    hub: hub,
                    result: result,
                    accessibilityMode: accessibilityMode,
                    obstacleActive: obstacleActive,
                    rerouted: rerouted,
                  ),
                  const SizedBox(height: 12),
                  _NodeListCard(hub: hub, activeNodes: activeNodes),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drag handle + title row. This is the 52px sliver left visible when the sheet
/// is minimised, so it carries both the drag affordance and the close button.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.hub,
    required this.isOpen,
    required this.onToggle,
  });

  final SimeDarbyHub hub;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -180 && !isOpen) onToggle();
        if (velocity > 180 && isOpen) onToggle();
      },
      child: Column(
        children: <Widget>[
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 36,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 14),
                const Icon(
                  Icons.directions_walk,
                  size: 18,
                  color: AppColors.routeAccessible,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'PLAN AN ACCESSIBLE TRIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        hub.name,
                        style: const TextStyle(
                          color: AppColors.sdpGreyMid,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _SheetToggleButton(isOpen: isOpen, onTap: onToggle),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating route legend, positioned by the host above the minimised bar.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.sdpCharcoal.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x38000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LegendChip(color: Color(0xFF10B981), label: 'OKU-safe route'),
          SizedBox(height: 5),
          _LegendChip(color: Color(0xFFEF4444), label: 'Stairs / obstacle'),
          SizedBox(height: 5),
          _LegendChip(color: Color(0xFF8F8F8F), label: 'Other route'),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Lists the hub's real-coordinate pedestrian / OKU wayfinding nodes.
class _NodeListCard extends StatelessWidget {
  const _NodeListCard({required this.hub, required this.activeNodes});

  final SimeDarbyHub hub;
  final List<HubNode> activeNodes;

  @override
  Widget build(BuildContext context) {
    final activeIds = <String>{for (final node in activeNodes) node.id};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sdpCharcoalSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.signpost_outlined,
                size: 18,
                color: AppColors.routeAccessible,
              ),
              const SizedBox(width: 8),
              const Text(
                'Wayfinding nodes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hub.focusArea,
            style: const TextStyle(color: AppColors.sdpGreyMid, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          for (final node in hub.nodes)
            _NodeRow(node: node, onRoute: activeIds.contains(node.id)),
        ],
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.onRoute});

  final HubNode node;
  final bool onRoute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: onRoute
                  ? AppColors.routeAccessible.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(node.icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  node.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: onRoute ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    if (onRoute)
                      const _MiniTag(label: 'ON ROUTE', color: AppColors.routeAccessible),
                    _MiniTag(
                      label: node.stepFree ? 'STEP-FREE' : 'STAIRS',
                      color: node.stepFree
                          ? AppColors.routeAccessible
                          : const Color(0xFFFF6B6B),
                    ),
                    if (node.covered)
                      const _MiniTag(label: 'COVERED', color: Color(0xFFFFC46B)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// A single fact row used by the node detail sheet.
class _NodeFact extends StatelessWidget {
  const _NodeFact({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// `✕` while the sheet is open, `🔼` while it is minimised.
class _SheetToggleButton extends StatelessWidget {
  const _SheetToggleButton({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isOpen ? 'Minimise trip planner' : 'Expand trip planner',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOpen ? Icons.close : Icons.keyboard_arrow_up,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
