import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/sime_darby/data/sime_darby_demo_data.dart';
import '../features/sime_darby/models/sime_darby_hub.dart';
import '../features/sime_darby/services/accessible_pathfinder.dart';
import '../features/sime_darby/services/route_hazards.dart';
import '../features/sime_darby/widgets/navigation_panels.dart';
import '../features/sime_darby/widgets/route_hazards_card.dart';
import '../features/sime_darby/widgets/route_metrics_card.dart';
import '../features/sime_darby/widgets/route_search_panel.dart';
import '../features/sime_darby/widgets/sime_darby_map.dart';
import '../features/sime_darby/widgets/sime_darby_selector.dart';
import '../models/obstacle.dart';
import '../models/profile.dart';
import '../models/report.dart';
import '../state/app_scope.dart';
import 'new_report_screen.dart';
import 'report_detail_screen.dart';

/// Full-screen 3D wayfinding map for Sime Darby Property.
///
/// The MapLibre 3D map fills the viewport and every control floats above it:
/// frosted township chips at the top and a draggable trip sheet at the bottom
/// (minimised → half → full). The map never re-lays-out when the sheet moves.
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  static const AccessiblePathfinder _pathfinder = AccessiblePathfinder();

  static const double _min = 0.15;
  static const double _mid = 0.5;
  static const double _max = 0.92;

  /// Map buttons and the legend only show once the sheet is nearly minimised.
  static const double _controlsThreshold = 0.3;

  static const double _gap = 12;

  final DraggableScrollableController _sheet = DraggableScrollableController();

  int _hubIndex = 0;
  AccessibilityNeed _need = AccessibilityNeed.wheelchair;
  bool _controlsVisible = false;
  bool _bannerVisible = true;

  /// Index of the node the member is at while navigating; null when not.
  int? _navStep;

  bool _needSeeded = false;

  bool get _accessibilityMode => _need.isAccessible;

  /// Starts the route mode from the member's saved profile, once.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_needSeeded) return;
    _needSeeded = true;
    final profile = AppScope.of(context).profile;
    if (profile.needs.isEmpty) return;
    _need = switch (profile.needs.first) {
      MobilityNeed.wheelchair => AccessibilityNeed.wheelchair,
      MobilityNeed.walkingAid ||
      MobilityNeed.elderly ||
      MobilityNeed.stroller => AccessibilityNeed.crutchesElderly,
      MobilityNeed.visuallyImpaired => AccessibilityNeed.visualTactile,
      MobilityNeed.hearingImpaired =>
        profile.prefs.avoidStairs
            ? AccessibilityNeed.wheelchair
            : AccessibilityNeed.standard,
    };
  }

  SimeDarbyHub get _hub => SimeDarbyDemoData.hubs[_hubIndex];

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  static const PathResult _noRoute = PathResult(
    nodes: <HubNode>[],
    polyline: <LatLng>[],
    distanceMeters: 0,
    coveredMeters: 0,
    hasStairs: false,
  );

  /// Best route that avoids the walkways closed by [hazards]. When every way
  /// round is closed, falls back to the usual route so the user still gets
  /// directions, with the unavoidable obstacles flagged.
  PathResult _route({
    required bool accessible,
    required List<RouteHazard> hazards,
  }) {
    final blocked = <HubEdge>{for (final h in hazards) h.edge};
    return _pathfinder.findPath(
          hub: _hub,
          accessibleOnly: accessible,
          blockedEdges: blocked,
        ) ??
        _pathfinder.findPath(hub: _hub, accessibleOnly: accessible) ??
        _noRoute;
  }

  bool get _navigating => _navStep != null;

  /// Heading-up camera for the node at [step] on [route].
  NavCamera? _cameraFor(PathResult route, int step) {
    final nodes = route.nodes;
    if (nodes.length < 2) return null;
    final last = nodes.length - 1;
    final from = step >= last ? nodes[last - 1] : nodes[step];
    final to = step >= last ? nodes[last] : nodes[step + 1];
    return NavCamera(
      position: nodes[step.clamp(0, last)].position,
      bearing: const Distance().bearing(from.position, to.position),
    );
  }

  void _startNavigation(PathResult route) {
    if (route.nodes.length < 2) return;
    setState(() {
      _navStep = 0;
      _controlsVisible = true;
    });
  }

  void _nextStep(PathResult route) {
    final step = _navStep;
    if (step == null || step >= route.nodes.length - 1) return;
    setState(() => _navStep = step + 1);
  }

  void _endNavigation() {
    setState(() {
      _navStep = null;
      _controlsVisible = false;
    });
  }

  void _onHubChanged(int index) {
    if (index == _hubIndex) return;
    setState(() => _hubIndex = index);
  }

  Future<void> _animateSheetTo(double size) async {
    if (!_sheet.isAttached) return;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    await _sheet.animateTo(
      size,
      duration: Duration(milliseconds: reduceMotion ? 1 : 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// Header tap: minimise when open, bring up to half height when minimised.
  void _toggleSheet() {
    if (!_sheet.isAttached) return;
    _animateSheetTo(_sheet.size > _min + 0.05 ? _min : _mid);
  }

  /// Called by the map when the user pans / zooms it themselves.
  void _collapseSheet() {
    if (!_sheet.isAttached || _sheet.size <= _min + 0.02) return;
    _animateSheetTo(_min);
  }

  bool _onSheetExtent(DraggableScrollableNotification notification) {
    final visible = notification.extent <= _controlsThreshold;
    if (visible != _controlsVisible) setState(() => _controlsVisible = visible);
    return false;
  }

  Report _toReport(Obstacle obstacle) => Report(
    id: obstacle.id,
    type: obstacle.type.label,
    location: obstacle.location,
    description: obstacle.description,
    position: obstacle.position,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    confirmations: obstacle.confirms,
    clearances: obstacle.clearances,
  );

  void _openHazard(RouteHazard hazard) {
    ReportDetailScreen.open(context, _toReport(hazard.obstacle), mine: false);
  }

  Future<void> _reportHere() async {
    final sent = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewReportScreen(initialHub: _hub),
      ),
    );
    if (sent != true || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Report sent. Routes here now avoid it.')),
      );
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
            Row(
              children: <Widget>[
                Icon(node.iconData, size: 24, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    node.label,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _hub.subtitle,
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _NodeFact(
              icon: node.stepFree
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.exclamationmark_triangle_fill,
              label: node.stepFree
                  ? 'Step-free waypoint'
                  : 'Stairs present — not OKU accessible',
              color: node.stepFree ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(height: 8),
            _NodeFact(
              icon: node.covered ? Icons.umbrella : Icons.wb_sunny_outlined,
              label: node.covered
                  ? 'Covered / weather-protected'
                  : 'Open air walkway',
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
    final reports = AppScope.of(context).communityObstacles;
    final mode = _accessibilityMode;

    final hazards = RouteHazards.forHub(hub, reports, accessible: mode);
    final active = _route(accessible: mode, hazards: hazards);
    final usual = _route(accessible: mode, hazards: const <RouteHazard>[]);
    final assessed = RouteHazards.assess(hazards, usual: usual, active: active);
    final alternate = _route(
      accessible: !mode,
      hazards: RouteHazards.forHub(hub, reports, accessible: !mode),
    );
    final avoided = assessed
        .where((h) => h.impact == HazardImpact.avoided)
        .length;
    final onRoute = assessed
        .where((h) => h.impact == HazardImpact.onRoute)
        .length;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final navStep = _navStep;
    final navCamera = navStep == null ? null : _cameraFor(active, navStep);

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlsBottom = constraints.maxHeight * _min + _gap;
        final sheetMaxWidth = constraints.maxWidth < 560
            ? constraints.maxWidth
            : 560.0;

        return Stack(
          children: <Widget>[
            // 1. Edge-to-edge full-screen 3D map.
            Positioned.fill(
              child: SimeDarbyMap(
                hub: hub,
                activeRoute: active,
                alternateRoute: alternate,
                accessibilityMode: _accessibilityMode,
                hazards: assessed,
                onHazardTap: _openHazard,
                navCamera: navCamera,
                onNodeTap: _showNodeInfo,
                onUserInteracted: navStep == null ? _collapseSheet : null,
                bottomInset: navStep == null ? controlsBottom : 190,
                showMapControls: _controlsVisible,
              ),
            ),

            // 2. Township chips, or the next-step banner while navigating.
            Positioned(
              top: _gap,
              left: 0,
              right: 0,
              child: navStep != null
                  ? PointerInterceptor(
                      child: NavigationBanner(
                        route: active,
                        step: navStep,
                        arrivedLabel: hub.pinBLabel,
                        hazardsAhead: onRoute,
                      ),
                    )
                  : SimeDarbySelector(
                      hubs: SimeDarbyDemoData.hubs,
                      selectedIndex: _hubIndex,
                      onChanged: _onHubChanged,
                      bannerVisible: _bannerVisible,
                      onToggleBanner: () =>
                          setState(() => _bannerVisible = !_bannerVisible),
                    ),
            ),

            // 3. Legend, clear of the minimised sheet; hidden while it is open.
            Positioned(
              left: _gap,
              bottom: controlsBottom,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _controlsVisible && !_navigating ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible || _navigating,
                  child: PointerInterceptor(child: const _MapLegend()),
                ),
              ),
            ),

            // 4. Navigation panel while walking, otherwise the draggable trip sheet.
            if (navStep != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: sheetMaxWidth),
                    child: PointerInterceptor(
                      child: NavigationPanel(
                        route: active,
                        step: navStep,
                        onNext: () => _nextStep(active),
                        onEnd: _endNavigation,
                        onReport: _reportHere,
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: sheetMaxWidth),
                    child: NotificationListener<DraggableScrollableNotification>(
                      onNotification: _onSheetExtent,
                      child: DraggableScrollableSheet(
                        controller: _sheet,
                        initialChildSize: _mid,
                        minChildSize: _min,
                        maxChildSize: _max,
                        snap: true,
                        snapSizes: const <double>[_min, _mid],
                        builder: (context, scroll) => DecoratedBox(
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppTheme.radiusXl),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Color(0x261E2B22),
                                blurRadius: 18,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppTheme.radiusXl),
                            ),
                            // Stops wheel / drag events on the sheet from also
                            // reaching the map underneath (which zoomed it out).
                            child: PointerInterceptor(
                              child: ListView(
                                controller: scroll,
                                padding: EdgeInsets.zero,
                                children: <Widget>[
                                  _SheetHeader(
                                    hub: hub,
                                    result: active,
                                    onTap: _toggleSheet,
                                    onStart: active.nodes.length < 2
                                        ? null
                                        : () => _startNavigation(active),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      bottomSafe + 24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        RouteSearchPanel(
                                          fromLabel: hub.pinALabel,
                                          toLabel: hub.pinBLabel,
                                          need: _need,
                                          onNeedChanged: (need) =>
                                              setState(() => _need = need),
                                          onVoiceTap: _onVoiceTap,
                                        ),
                                        const SizedBox(height: 16),
                                        RouteMetricsCard(
                                          hub: hub,
                                          result: active,
                                          accessibilityMode: _accessibilityMode,
                                          avoidedHazards: avoided,
                                          hazardsOnRoute: onRoute,
                                        ),
                                        const SizedBox(height: 12),
                                        RouteHazardsCard(
                                          hazards: assessed,
                                          onOpen: _openHazard,
                                          onReport: _reportHere,
                                        ),
                                        const SizedBox(height: 12),
                                        _NodeListCard(
                                          hub: hub,
                                          activeNodes: active.nodes,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

/// Drag handle + one-line route summary. This is the part left visible when the
/// sheet is minimised, so it already answers "where to, how far, how long".
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.hub,
    required this.result,
    required this.onTap,
    required this.onStart,
  });

  final SimeDarbyHub hub;
  final PathResult result;
  final VoidCallback onTap;

  /// null when there is no route to follow.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      AccessiblePathfinder.formatDistance(result.distanceMeters),
      AccessiblePathfinder.formatMinutes(result.walkMinutes),
      if (result.stepFree) 'Step-free',
    ].join(' · ');

    return Semantics(
      button: true,
      label:
          'Trip planner, ${hub.name}. $summary. Double tap to expand or minimise.',
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_walk,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          hub.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(CupertinoIcons.location_north_fill, size: 18),
                    label: const Text('Start'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating route legend: frosted, so the map reads through it.
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: AppColors.surface.withValues(alpha: 0.9),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LegendChip(color: Color(0xFF10B981), label: 'OKU-safe route'),
              SizedBox(height: 6),
              _LegendChip(color: Color(0xFFEF4444), label: 'Stairs / obstacle'),
              SizedBox(height: 6),
              _LegendChip(color: Color(0xFF8F8F8F), label: 'Other route'),
            ],
          ),
        ),
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
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.signpost_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Along the way',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: onRoute ? AppColors.mint : AppColors.field,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              node.iconData,
              size: 19,
              color: onRoute ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  node.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: onRoute ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    if (onRoute)
                      const _MiniTag(
                        label: 'On route',
                        color: AppColors.primary,
                      ),
                    _MiniTag(
                      label: node.stepFree ? 'Step-free' : 'Stairs',
                      color: node.stepFree
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    if (node.covered)
                      const _MiniTag(label: 'Covered', color: AppColors.accentText),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// A single fact row used by the node detail sheet.
class _NodeFact extends StatelessWidget {
  const _NodeFact({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
