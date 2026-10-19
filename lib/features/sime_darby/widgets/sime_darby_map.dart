import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/location_service.dart';
import '../data/sime_darby_demo_data.dart';
import '../models/sime_darby_hub.dart';
import '../services/accessible_pathfinder.dart';
import '../services/route_hazards.dart';

/// Close-up, heading-up camera used while a trip is being navigated.
class NavCamera {
  const NavCamera({
    required this.position,
    required this.bearing,
    this.zoom = 19,
    this.pitch = 65,
  });

  final geo.LatLng position;

  /// Direction of travel in degrees; the map is rotated so it points up.
  final double bearing;
  final double zoom;
  final double pitch;

  @override
  bool operator ==(Object other) =>
      other is NavCamera &&
      other.position == position &&
      other.bearing == bearing &&
      other.zoom == zoom &&
      other.pitch == pitch;

  @override
  int get hashCode => Object.hash(position, bearing, zoom, pitch);
}

/// Real-world 3D street map for the Sime Darby Property demo.
///
/// Renders a tilted MapLibre vector map (OpenFreeMap "bright" - no API key)
/// with `fill-extrusion` 3D buildings, and draws the pedestrian / OKU routes
/// as street-following GeoJSON lines with a 3D casing plus animated direction
/// dashes. Pin A / Pin B and the accessibility nodes are mapOKU-styled badges
/// overlaid in a Stack (MapLibre renders a native view, so widgets go over the
/// map rather than between its layers).
class SimeDarbyMap extends StatefulWidget {
  const SimeDarbyMap({
    super.key,
    required this.hub,
    required this.activeRoute,
    required this.alternateRoute,
    required this.accessibilityMode,
    this.hazards = const <RouteHazard>[],
    this.onHazardTap,
    this.navCamera,
    this.onNodeTap,
    this.onUserInteracted,
    this.bottomInset = 12,
    this.showMapControls = true,
  });

  final SimeDarbyHub hub;

  /// The selected route (emerald when step-free, red when it has stairs).
  final PathResult activeRoute;

  /// The other route, drawn as a faint dashed reference line.
  final PathResult alternateRoute;

  final bool accessibilityMode;

  /// Community-reported obstacles on the hub's walkways.
  final List<RouteHazard> hazards;
  final ValueChanged<RouteHazard>? onHazardTap;

  /// When set, the camera follows the trip in a close 3D heading-up view.
  final NavCamera? navCamera;

  final ValueChanged<HubNode>? onNodeTap;

  /// Fired when the user pans / zooms / tilts the map themselves, so the host
  /// screen can collapse its floating bottom sheet (Google Maps behaviour).
  /// Programmatic camera animations do not trigger this.
  final VoidCallback? onUserInteracted;

  /// Space reserved at the bottom of the map for the host's floating controls.
  final double bottomInset;

  /// Hidden while the host's bottom sheet is expanded so the controls never sit
  /// underneath it.
  final bool showMapControls;

  @override
  State<SimeDarbyMap> createState() => _SimeDarbyMapState();
}

/// Emerald for OKU-safe routes, red for stairs / obstacles.
const String _availableRouteColor = '#10b981';
const String _stairsRouteColor = '#ef4444';

class _SimeDarbyMapState extends State<SimeDarbyMap> {
  static const _buildingLayer = 'mapoku-3d-buildings';
  static const _altSource = 'mapoku-alt-src';
  static const _altCasing = 'mapoku-alt-casing';
  static const _altLine = 'mapoku-alt-line';
  static const _activeSource = 'mapoku-active-src';
  static const _routeShadow = 'mapoku-route-shadow';
  static const _routeCasing = 'mapoku-route-casing';
  static const _routeMain = 'mapoku-route-main';
  static const _routeArrows = 'mapoku-route-arrows';
  static const _nodesSource = 'mapoku-nodes-src';
  static const _nodeHalo = 'mapoku-node-halo';

  /// Marching dash frames so direction markers flow along the route.
  static const List<List<double>> _dashFrames = <List<double>>[
    <double>[0.6, 3.4],
    <double>[1.1, 2.9],
    <double>[1.6, 2.4],
    <double>[2.1, 1.9],
    <double>[2.6, 1.4],
    <double>[2.1, 1.9],
    <double>[1.6, 2.4],
    <double>[1.1, 2.9],
  ];

  MapLibreMapController? _controller;
  bool _styleReady = false;
  Timer? _arrowTimer;
  int _arrowFrame = 0;

  /// True while the app (not the user) is moving the camera.
  bool _animatingCamera = false;

  /// Trailing camera events after a programmatic move are ignored briefly.
  DateTime _lastProgrammaticMove = DateTime.fromMillisecondsSinceEpoch(0);

  final Map<String, Offset> _overlayPositions = <String, Offset>{};
  DateTime _lastOverlayUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _stepFree => widget.activeRoute.stepFree;
  String get _routeColor =>
      _stepFree ? _availableRouteColor : _stairsRouteColor;
  String get _casingColor => _stepFree ? '#065f46' : '#7f1d1d';

  static String _hazardKey(List<RouteHazard> hazards) =>
      hazards.map((h) => '${h.obstacle.id}:${h.impact.name}').join('|');

  @override
  void didUpdateWidget(covariant SimeDarbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_styleReady) return;

    final hubChanged = oldWidget.hub.id != widget.hub.id;
    final routeChanged =
        oldWidget.activeRoute != widget.activeRoute ||
        oldWidget.alternateRoute != widget.alternateRoute ||
        _hazardKey(oldWidget.hazards) != _hazardKey(widget.hazards);

    if (oldWidget.navCamera != widget.navCamera) {
      final camera = widget.navCamera;
      if (camera != null) {
        _flyToNav(camera);
      } else if (!hubChanged) {
        _flyToHub();
      }
    }
    if (hubChanged) _flyToHub();
    if (hubChanged || routeChanged) {
      _refreshRouteSources();
      _refreshRouteColors();
      _updateOverlays(force: true);
    }
  }

  @override
  void dispose() {
    _arrowTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Style setup
  // ---------------------------------------------------------------------------

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      // 3D extruded buildings, reusing the style's existing vector source.
      await controller.addFillExtrusionLayer(
        SimeDarbyDemoData.buildingSourceId,
        _buildingLayer,
        FillExtrusionLayerProperties(
          fillExtrusionColor: '#d9e2ec',
          fillExtrusionOpacity: 0.75,
          fillExtrusionHeight: 26,
          fillExtrusionBase: 0,
        ),
        sourceLayer: SimeDarbyDemoData.buildingSourceLayer,
        minzoom: 13,
      );
    } catch (_) {
      // A style without building data still works - the routes stay visible.
    }

    await _addRouteLayers();
    await _refreshRouteSources();
    await _refreshRouteColors();

    _styleReady = true;
    await _flyToHub();
    _startArrowAnimation();
    _updateOverlays(force: true);
  }

  Future<void> _addRouteLayers() async {
    final controller = _controller;
    if (controller == null) return;

    // Reference route (the mode that is not currently selected).
    await controller.addGeoJsonSource(_altSource, _emptyLines());
    await controller.addLineLayer(
      _altSource,
      _altCasing,
      LineLayerProperties(
        lineColor: '#b9b9b9',
        lineOpacity: 0.35,
        lineWidth: 9,
        lineDasharray: <double>[1.4, 1.4],
      ),
    );
    await controller.addLineLayer(
      _altSource,
      _altLine,
      LineLayerProperties(
        lineColor: '#8f8f8f',
        lineOpacity: 0.65,
        lineWidth: 3,
        lineDasharray: <double>[1.4, 1.4],
      ),
    );

    // Active route: shadow + casing + core + animated direction dashes.
    await controller.addGeoJsonSource(_activeSource, _emptyLines());
    await controller.addLineLayer(
      _activeSource,
      _routeShadow,
      LineLayerProperties(
        lineColor: '#000000',
        lineOpacity: 0.22,
        lineWidth: 26,
      ),
    );
    await controller.addLineLayer(
      _activeSource,
      _routeCasing,
      LineLayerProperties(
        lineColor: _casingColor,
        lineOpacity: 0.9,
        lineWidth: 16,
      ),
    );
    await controller.addLineLayer(
      _activeSource,
      _routeMain,
      LineLayerProperties(lineColor: _routeColor, lineOpacity: 1, lineWidth: 8),
    );
    await controller.addLineLayer(
      _activeSource,
      _routeArrows,
      _arrowProperties(0),
    );

    // Node locations on the map surface.
    await controller.addGeoJsonSource(_nodesSource, _emptyPoints());
    await controller.addCircleLayer(
      _nodesSource,
      _nodeHalo,
      CircleLayerProperties(
        circleRadius: 6,
        circleColor: '#ffffff',
        circleOpacity: 0.95,
        circleStrokeColor: '#1e1e1e',
        circleStrokeWidth: 2,
      ),
    );
  }

  /// The direction-dash paint must always carry every property, because
  /// `setLayerProperties` writes nulls for omitted keys.
  LineLayerProperties _arrowProperties(int frame) {
    return LineLayerProperties(
      lineColor: '#ffffff',
      lineOpacity: 0.95,
      lineWidth: 3.6,
      lineDasharray: _dashFrames[frame % _dashFrames.length],
    );
  }

  // ---------------------------------------------------------------------------
  // Data + camera
  // ---------------------------------------------------------------------------

  Future<void> _refreshRouteSources() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setGeoJsonSource(
        _activeSource,
        _lineFeature(widget.activeRoute.polyline),
      );
      await controller.setGeoJsonSource(
        _altSource,
        _lineFeature(widget.alternateRoute.polyline),
      );
      await controller.setGeoJsonSource(
        _nodesSource,
        _pointFeatures(<geo.LatLng>[
          for (final node in widget.hub.nodes) node.position,
        ]),
      );
    } catch (_) {
      // The map may be mid-rebuild; the next update will retry.
    }
  }

  Future<void> _refreshRouteColors() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setLayerProperties(
        _routeCasing,
        LineLayerProperties(
          lineColor: _casingColor,
          lineOpacity: 0.9,
          lineWidth: 16,
        ),
      );
      await controller.setLayerProperties(
        _routeMain,
        LineLayerProperties(
          lineColor: _routeColor,
          lineOpacity: 1,
          lineWidth: 8,
        ),
      );
    } catch (_) {}
  }

  /// Flies to a navigation step: close in, tilted, facing the way to walk.
  Future<void> _flyToNav(NavCamera camera) async {
    final controller = _controller;
    if (controller == null) return;
    _animatingCamera = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _toMapLatLng(camera.position),
            zoom: camera.zoom,
            bearing: camera.bearing,
            tilt: camera.pitch,
          ),
        ),
        duration: const Duration(milliseconds: 1400),
      );
    } catch (_) {
      // Camera animation is best-effort.
    } finally {
      _animatingCamera = false;
      _lastProgrammaticMove = DateTime.now();
    }
  }

  /// Smoothly flies the camera to the selected hub's real coordinates.
  Future<void> _flyToHub() async {
    final controller = _controller;
    if (controller == null) return;
    _animatingCamera = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _toMapLatLng(widget.hub.center),
            zoom: widget.hub.zoom,
            bearing: widget.hub.bearing,
            tilt: widget.hub.pitch,
          ),
        ),
        duration: const Duration(milliseconds: 1500),
      );
    } catch (_) {
      // Camera animation is best-effort.
    } finally {
      _animatingCamera = false;
      _lastProgrammaticMove = DateTime.now();
    }
  }

  /// Camera tick: refresh the overlays and tell the host when the *user* moved.
  void _handleCameraMove() {
    _updateOverlays();
    if (_animatingCamera) return;
    if (DateTime.now().difference(_lastProgrammaticMove) <
        const Duration(milliseconds: 500)) {
      return;
    }
    widget.onUserInteracted?.call();
  }

  /// Marches the direction dashes forward along the route.
  void _startArrowAnimation() {
    _arrowTimer?.cancel();
    _arrowTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final controller = _controller;
      if (controller == null || !mounted) return;
      _arrowFrame++;
      try {
        await controller.setLayerProperties(
          _routeArrows,
          _arrowProperties(_arrowFrame),
        );
      } catch (_) {}
    });
  }

  /// Recentres the map on the device's real position via the geolocator-backed
  /// [LocationService] (the location permissions are already declared for
  /// Android and iOS).
  Future<void> _goToMyLocation() async {
    final controller = _controller;
    if (controller == null) return;

    final point = await const LocationService().currentLatLng();
    if (!mounted) return;

    if (point == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is needed to centre on your position.',
            ),
          ),
        );
      return;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _toMapLatLng(point),
            zoom: 17.5,
            bearing: widget.hub.bearing,
            tilt: widget.hub.pitch,
          ),
        ),
        duration: const Duration(milliseconds: 900),
      );
    } catch (_) {
      // Camera animation is best-effort.
    } finally {
      _animatingCamera = false;
      _lastProgrammaticMove = DateTime.now();
    }
  }

  // ---------------------------------------------------------------------------
  // Floating badges (mapOKU Pin A / Pin B + node chips)
  // ---------------------------------------------------------------------------

  /// Step-free nodes shown as compact badges; the endpoints are Pin A / Pin B.
  List<HubNode> get _badgeNodes {
    final hub = widget.hub;
    return hub.nodes
        .where(
          (node) =>
              node.stepFree &&
              node.id != hub.startNodeId &&
              node.id != hub.endNodeId,
        )
        .toList();
  }

  Future<void> _updateOverlays({bool force = false}) async {
    final controller = _controller;
    if (controller == null || !_styleReady || !mounted) return;

    final now = DateTime.now();
    if (!force &&
        now.difference(_lastOverlayUpdate) < const Duration(milliseconds: 70)) {
      return;
    }
    _lastOverlayUpdate = now;

    final targets = <String, geo.LatLng>{
      'pinA': widget.hub.pinA,
      'pinB': widget.hub.pinB,
      if (widget.navCamera != null) 'nav': widget.navCamera!.position,
      for (final node in _badgeNodes) 'node:${node.id}': node.position,
    };

    for (final hazard in widget.hazards) {
      targets['hazard:${hazard.obstacle.id}'] = hazard.obstacle.position;
    }

    final next = <String, Offset>{};
    for (final entry in targets.entries) {
      try {
        final point = await controller.toScreenLocation(
          _toMapLatLng(entry.value),
        );
        next[entry.key] = Offset(point.x.toDouble(), point.y.toDouble());
      } catch (_) {
        // Off-screen or behind the camera.
      }
    }

    if (!mounted) return;
    setState(() {
      _overlayPositions
        ..clear()
        ..addAll(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        MapLibreMap(
          styleString: SimeDarbyDemoData.styleUrl,
          initialCameraPosition: CameraPosition(
            target: _toMapLatLng(widget.hub.center),
            zoom: widget.hub.zoom,
            bearing: widget.hub.bearing,
            tilt: widget.hub.pitch,
          ),
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: _onStyleLoaded,
          onCameraMove: (_) => _handleCameraMove(),
          onCameraIdle: () => _updateOverlays(force: true),
          trackCameraPosition: true,
          compassEnabled: false,
          logoEnabled: false,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          minMaxZoomPreference: const MinMaxZoomPreference(13, 20),
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
        ),
        ..._overlayWidgets(),
      ],
    );
  }

  List<Widget> _overlayWidgets() {
    final widgets = <Widget>[];

    final pinA = _overlayPositions['pinA'];
    if (pinA != null) {
      widgets.add(
        _positionedPin(pinA, 'A', AppColors.forest, widget.hub.startNodeId),
      );
    }

    final pinB = _overlayPositions['pinB'];
    if (pinB != null) {
      widgets.add(
        _positionedPin(pinB, 'B', AppColors.accent, widget.hub.endNodeId),
      );
    }

    final me = _overlayPositions['nav'];
    if (me != null && widget.navCamera != null) {
      widgets.add(
        Positioned(
          left: me.dx - 14,
          top: me.dy - 14,
          child: const IgnorePointer(child: _YouAreHere()),
        ),
      );
    }

    for (final node in _badgeNodes) {
      final position = _overlayPositions['node:${node.id}'];
      if (position == null) continue;
      widgets.add(_positionedBadge(position, node));
    }

    for (final hazard in widget.hazards) {
      final position = _overlayPositions['hazard:${hazard.obstacle.id}'];
      if (position == null) continue;
      widgets.add(
        Positioned(
          left: position.dx - 22,
          top: position.dy - 22,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onHazardTap == null
                ? null
                : () => widget.onHazardTap!(hazard),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: _HazardMarker(hazard: hazard)),
            ),
          ),
        ),
      );
    }

    if (widget.showMapControls) {
      widgets.add(
        Positioned(
          right: 12,
          bottom: widget.bottomInset,
          child: _LocateButton(onTap: _goToMyLocation),
        ),
      );
    }

    return widgets;
  }

  /// Pin A / Pin B teardrop badge; the tip of the teardrop marks the coordinate.
  Widget _positionedPin(
    Offset anchor,
    String letter,
    Color color,
    String nodeId,
  ) {
    final node = widget.hub.nodeById(nodeId);
    return Positioned(
      left: anchor.dx - 22,
      top: anchor.dy - 42,
      child: GestureDetector(
        onTap: widget.onNodeTap == null ? null : () => widget.onNodeTap!(node),
        child: _PinBadge(letter: letter, color: color),
      ),
    );
  }

  Widget _positionedBadge(Offset anchor, HubNode node) {
    return Positioned(
      left: anchor.dx - 74,
      top: anchor.dy - 36,
      width: 148,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: widget.onNodeTap == null
              ? null
              : () => widget.onNodeTap!(node),
          child: _NodeBadge(
            icon: node.iconData,
            label: node.label,
            covered: node.covered,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GeoJSON helpers
  // ---------------------------------------------------------------------------

  LatLng _toMapLatLng(geo.LatLng point) =>
      LatLng(point.latitude, point.longitude);

  Map<String, dynamic> _emptyLines() => _lineFeature(const <geo.LatLng>[]);

  Map<String, dynamic> _lineFeature(List<geo.LatLng> points) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': <List<double>>[
              for (final point in points)
                <double>[point.longitude, point.latitude],
            ],
          },
        },
      ],
    };
  }

  Map<String, dynamic> _emptyPoints() => _pointFeatures(const <geo.LatLng>[]);

  Map<String, dynamic> _pointFeatures(List<geo.LatLng> points) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        for (final point in points)
          <String, dynamic>{
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[point.longitude, point.latitude],
            },
          },
      ],
    };
  }
}

/// mapOKU teardrop marker: black for Pin A, orange/brown for Pin B.
class _PinBadge extends StatelessWidget {
  const _PinBadge({required this.letter, required this.color});

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
                bottomRight: Radius.circular(15),
                bottomLeft: Radius.circular(2),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x45000000),
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact floating badge for a key accessibility node.
class _NodeBadge extends StatelessWidget {
  const _NodeBadge({
    required this.icon,
    required this.label,
    required this.covered,
  });

  final IconData icon;
  final String label;
  final bool covered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sdpCharcoal.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.routeAccessible.withValues(alpha: 0.75),
          width: 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (covered) ...<Widget>[
            const SizedBox(width: 5),
            const Icon(
              Icons.umbrella,
              size: 10,
              color: AppColors.routeAccessible,
            ),
          ],
        ],
      ),
    );
  }
}

/// Blue "you are here" dot shown while navigating.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x662563EB), blurRadius: 14, spreadRadius: 4),
        ],
      ),
    );
  }
}

/// Marker for a community-reported obstacle: a round hazard-coloured badge
/// with the obstacle's icon. Red when the route still passes it, amber when
/// the route was bent around it, grey when it is on a walkway not in use.
class _HazardMarker extends StatelessWidget {
  const _HazardMarker({required this.hazard});

  final RouteHazard hazard;

  @override
  Widget build(BuildContext context) {
    final color = switch (hazard.impact) {
      HazardImpact.onRoute => AppColors.danger,
      HazardImpact.avoided => AppColors.construction,
      HazardImpact.nearby => AppColors.sdpGreyMid,
    };

    return Semantics(
      button: true,
      label: '${hazard.obstacle.type.label} reported here',
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(hazard.obstacle.type.icon, size: 18, color: Colors.white),
      ),
    );
  }
}

/// Recentre-on-my-location control, matching the mapOKU controls.
class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onTap(),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(CupertinoIcons.location_fill, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }
}
