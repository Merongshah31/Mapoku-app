import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../state/routes_controller.dart';
import '../../widgets/map_pins.dart';
import '../../widgets/obstacle_ui.dart';

/// Live OpenStreetMap view of the selected Sime Darby Property township.
/// moss solid = OKU-safe route, grey dashed = standard route,
/// amber dots = reported obstacles, A = start, B = destination, C = suggestion.
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, required this.bottomInset, required this.topInset});

  /// Space the bottom sheet / top bar cover, so routes are framed in the
  /// visible part of the map instead of hiding under the sheet.
  final double bottomInset;
  final double topInset;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _map = MapController();
  bool _ready = false;
  Object? _framedFor;

  // SJCC / SJ7 until the township list loads.
  static final _start = LatLng(3.0833, 101.5878);

  void _frame(RoutesController c) {
    final plan = c.plan;
    final t = c.township;
    final key = plan == null ? t?.id : (plan, c.phase == RoutesPhase.navigating ? c.selected : null);
    if (!_ready || key == _framedFor) return;
    _framedFor = key;

    if (plan == null) {
      if (t == null) return;
      // Frame the start point and the popular places, above the sheet.
      _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([t.start.position, for (final p in t.popular) p.position]),
        padding: EdgeInsets.fromLTRB(64, widget.topInset + 48, 64, widget.bottomInset + 48),
        maxZoom: 17.5,
      ));
      return;
    }
    final points = c.phase == RoutesPhase.navigating
        ? c.selectedOption!.path
        : [...plan.stepFree.path, ...plan.standard.path];
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: EdgeInsets.fromLTRB(48, widget.topInset + 24, 48, widget.bottomInset + 24),
      maxZoom: 17,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoutesController>();
    final plan = c.plan;
    final navigating = c.phase == RoutesPhase.navigating;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _frame(c);
    });

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _start,
        initialZoom: 15,
        backgroundColor: Palette.page,
        onMapReady: () {
          _ready = true;
          _frame(c);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.mapoku',
        ),
        if (plan != null) PolylineLayer(polylines: _routeLines(plan, c.selected, navigating)),
        MarkerLayer(markers: plan == null ? _idleMarkers(c.township) : _planMarkers(context, plan, c.selected, navigating)),
      ],
    );
  }

  List<Polyline> _routeLines(RoutePlan plan, RouteKind selected, bool navigating) {
    Polyline line(RouteOption o) {
      final isSelected = o.kind == selected;
      final isStepFree = o.kind == RouteKind.stepFree;
      return Polyline(
        points: o.path,
        strokeWidth: isSelected ? 6 : 4,
        color: (isStepFree ? Palette.moss : Palette.routeGrey).withValues(alpha: isSelected ? 1 : 0.45),
        pattern: isStepFree ? const StrokePattern.solid() : StrokePattern.dashed(segments: const [10, 8]),
        borderStrokeWidth: isSelected ? 2 : 0,
        borderColor: Colors.white,
      );
    }

    final selectedLine = line(plan.option(selected));
    if (navigating) return [selectedLine];
    final other = line(plan.option(selected == RouteKind.stepFree ? RouteKind.standard : RouteKind.stepFree));
    return [other, selectedLine]; // selected drawn last, on top
  }

  List<Marker> _idleMarkers(Township? t) => [
        if (t != null) ...[
          for (final p in t.popular)
            Marker(
              point: p.position,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: Semantics(label: p.name, child: const LetterPin(letter: '•', color: Palette.moss, size: 26)),
            ),
          Marker(point: t.start.position, width: 34, height: 34, child: const YouAreHere()),
        ],
      ];

  List<Marker> _planMarkers(BuildContext context, RoutePlan plan, RouteKind selected, bool navigating) {
    final showStandard = !navigating || selected == RouteKind.standard;
    final showStepFree = !navigating || selected == RouteKind.stepFree;
    final suggestionPlace = plan.stepFree.destination;
    final hasSeparateSuggestion = plan.suggestion != null;

    return [
      for (final o in plan.obstacles)
        Marker(
          point: o.position,
          width: 44,
          height: 44,
          child: Semantics(
            label: 'Obstacle: ${o.title}',
            button: true,
            child: GestureDetector(
              onTap: () => showObstacleSheet(context, o),
              child: ObstacleDot(dimmed: selected == RouteKind.stepFree && !navigating),
            ),
          ),
        ),
      Marker(
        point: plan.origin.position,
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: const LetterPin(letter: 'A', color: Palette.ink),
      ),
      if (showStandard)
        Marker(
          point: plan.requested.position,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: const LetterPin(letter: 'B', color: Palette.amber),
        ),
      if (showStepFree && hasSeparateSuggestion)
        Marker(
          point: suggestionPlace.position,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: const LetterPin(letter: 'C', color: Palette.moss),
        ),
    ];
  }
}
