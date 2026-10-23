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
    this.showNoiseZones = true,
    this.onToggleNoiseZones,
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

  /// Draws the red noise-zone heatmap from the hub's IoT sound sensors.
  final bool showNoiseZones;

  /// Fired by the map's noise toggle button.
  final VoidCallback? onToggleNoiseZones;

  @override
  State<SimeDarbyMap> createState() => _SimeDarbyMapState();
}

/// Emerald for OKU-safe routes, red for stairs / obstacles.
const String _availableRouteColor = '#10b981';
const String _stairsRouteColor = '#ef4444';

/// IoT sensory heatmap palette. The stops mirror [NoiseZone], so the gradient
/// layers, the decibel badges and the on-map legend always agree.
const String _noiseCalmColor = '#38bdf8';
const String _noiseCalmGreen = '#22c55e';
const String _noiseModerateColor = '#f59e0b';
const String _noiseWarmColor = '#f97316';
const String _noiseDangerColor = '#ef4444';
const String _noiseDangerDeepColor = '#b91c1c';

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
  static const _noiseSource = 'mapoku-noise-src';
  static const _noiseHeat = 'mapoku-noise-heat';
  static const _noiseGlow = 'mapoku-noise-glow';
  static const _noiseCore = 'mapoku-noise-core';
  static const _noiseAlarmSource = 'mapoku-noise-alarm-src';
  static const _noisePulse = 'mapoku-noise-pulse';

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

  /// Breathes the red danger rings so the loud zone reads as "live".
  Timer? _noiseTimer;
  int _noisePulseFrame = 0;

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
    if (oldWidget.showNoiseZones != widget.showNoiseZones) {
      _applyNoiseVisibility();
      _updateOverlays(force: true);
    }
  }

  @override
  void dispose() {
    _arrowTimer?.cancel();
    _noiseTimer?.cancel();
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
    await _applyNoiseVisibility();

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

    // IoT sensory heatmap (neurodivergent mode): a smooth density gradient
    // under the routes, a zone coloured halo and core per sensor, and a
    // pulsing red ring on every sensor above 75 dB.
    await controller.addGeoJsonSource(
      _noiseSource,
      _noiseFeature(const <NoiseSensor>[]),
    );
    await controller.addHeatmapLayer(
      _noiseSource,
      _noiseHeat,
      _noiseHeatProperties(visible: false),
      // Below the route so the glowing path always stays readable.
      belowLayerId: _routeShadow,
    );
    await controller.addCircleLayer(
      _noiseSource,
      _noiseGlow,
      _noiseGlowProperties(visible: false),
    );
    await controller.addGeoJsonSource(
      _noiseAlarmSource,
      _noiseFeature(const <NoiseSensor>[]),
    );
    await controller.addCircleLayer(
      _noiseAlarmSource,
      _noisePulse,
      _noisePulseProperties(1),
    );
    await controller.addCircleLayer(
      _noiseSource,
      _noiseCore,
      _noiseCoreProperties(visible: false),
    );
  }

  // ---------------------------------------------------------------------------
  // IoT sensory heatmap
  // ---------------------------------------------------------------------------

  /// The loud sensors that get the pulsing red ring.
  List<NoiseSensor> get _dangerSensors => widget.hub.noiseSensors
      .where((sensor) => sensor.zone.isDanger)
      .toList();

  /// Data driven colour shared by the halo and the core: calm blue, calm
  /// green, amber, then the danger red.
  static List<dynamic> get _zoneColorExpression => <dynamic>[
    'interpolate',
    <dynamic>['linear'],
    <dynamic>['get', 'db'],
    45, _noiseCalmColor,
    55, _noiseCalmGreen,
    65, _noiseModerateColor,
    75, _noiseWarmColor,
    85, _noiseDangerColor,
  ];

  /// Paint for the smooth, continuous heatmap gradient.
  ///
  /// Every property is always supplied, because `setLayerProperties` writes
  /// nulls for omitted keys, which would reset the layer.
  HeatmapLayerProperties _noiseHeatProperties({required bool visible}) {
    return HeatmapLayerProperties(
      // Quiet sensors barely contribute while loud ones dominate the density,
      // so the hot spots go red and the calm walkways stay blue / green.
      heatmapWeight: <dynamic>[
        'interpolate',
        <dynamic>['linear'],
        <dynamic>['get', 'db'],
        40, 0.04,
        55, 0.22,
        70, 0.55,
        85, 1,
      ],
      heatmapRadius: <dynamic>[
        'interpolate',
        <dynamic>['linear'],
        <dynamic>['zoom'],
        13, 16,
        17, 40,
        20, 76,
      ],
      heatmapIntensity: 1.05,
      // Density to colour ramp: soft blue, green, amber, orange, then red.
      heatmapColor: <dynamic>[
        'interpolate',
        <dynamic>['linear'],
        <dynamic>[Expressions.heatmapDensity],
        0, 'rgba(56,189,248,0)',
        0.12, _noiseCalmColor,
        0.3, _noiseCalmGreen,
        0.55, _noiseModerateColor,
        0.74, _noiseWarmColor,
        1, _noiseDangerColor,
      ],
      heatmapOpacity: visible ? 0.78 : 0,
    );
  }

  /// Zone coloured halo, wider on the louder sensors.
  CircleLayerProperties _noiseGlowProperties({required bool visible}) {
    return CircleLayerProperties(
      circleRadius: <dynamic>[
        'interpolate',
        <dynamic>['linear'],
        <dynamic>['get', 'db'],
        40, 30,
        55, 40,
        70, 54,
        90, 72,
      ],
      circleColor: _zoneColorExpression,
      circleOpacity: visible ? 0.2 : 0,
      circleBlur: 0.9,
      circleStrokeWidth: 0,
    );
  }

  /// The solid marker that pins each sensor to its exact coordinate.
  CircleLayerProperties _noiseCoreProperties({required bool visible}) {
    return CircleLayerProperties(
      circleRadius: 15,
      circleColor: _zoneColorExpression,
      circleOpacity: visible ? 0.92 : 0,
      circleStrokeColor: '#ffffff',
      circleStrokeWidth: visible ? 2 : 0,
    );
  }

  /// The breathing red ring around the loud sensors. [phase] runs from 0
  /// (tight and solid) to 1 (wide and fully faded).
  CircleLayerProperties _noisePulseProperties(double phase) {
    return CircleLayerProperties(
      circleRadius: 22 + 34 * phase,
      circleColor: _noiseDangerColor,
      circleOpacity: 0.45 * (1 - phase),
      circleBlur: 0.55,
      circleStrokeColor: _noiseDangerDeepColor,
      circleStrokeWidth: 2 * (1 - phase),
    );
  }

  /// Shows or hides the IoT sensory heatmap and starts or stops its pulse.
  ///
  /// Paint properties are always fully specified because
  /// `setLayerProperties` writes nulls for omitted keys.
  Future<void> _applyNoiseVisibility() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    final visible = widget.showNoiseZones;

    if (visible) {
      _startNoisePulse();
    } else {
      _noiseTimer?.cancel();
      _noiseTimer = null;
    }

    try {
      await controller.setLayerProperties(
        _noiseHeat,
        _noiseHeatProperties(visible: visible),
      );
      await controller.setLayerProperties(
        _noiseGlow,
        _noiseGlowProperties(visible: visible),
      );
      await controller.setLayerProperties(
        _noiseCore,
        _noiseCoreProperties(visible: visible),
      );
      await controller.setLayerProperties(
        _noisePulse,
        _noisePulseProperties(visible ? 0 : 1),
      );
    } catch (_) {
      // The map may be mid-rebuild; the next update will retry.
    }
  }

  /// Breathes the red danger rings so the loud zone reads as "live".
  void _startNoisePulse() {
    _noiseTimer?.cancel();
    _noiseTimer = Timer.periodic(const Duration(milliseconds: 110), (_) async {
      final controller = _controller;
      if (controller == null || !mounted) return;
      _noisePulseFrame = (_noisePulseFrame + 1) % 14;
      try {
        await controller.setLayerProperties(
          _noisePulse,
          _noisePulseProperties(_noisePulseFrame / 13),
        );
      } catch (_) {
        // The map may be mid-rebuild; the next frame will retry.
      }
    });
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
      await controller.setGeoJsonSource(
        _noiseSource,
        _noiseFeature(widget.hub.noiseSensors),
      );
      await controller.setGeoJsonSource(
        _noiseAlarmSource,
        _noiseFeature(_dangerSensors),
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

    if (widget.showNoiseZones) {
      for (final sensor in widget.hub.noiseSensors) {
        targets['noise:${sensor.id}'] = sensor.position;
      }
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

    if (widget.showNoiseZones) {
      for (final sensor in widget.hub.noiseSensors) {
        final position = _overlayPositions['noise:${sensor.id}'];
        if (position == null) continue;
        widgets.add(
          Positioned(
            key: ValueKey<String>('noise-badge-${sensor.id}'),
            left: position.dx - 34,
            top: position.dy - 13,
            child: IgnorePointer(
              child: _NoiseBadge(
                key: ValueKey<String>('noise-pill-${sensor.id}'),
                sensor: sensor,
              ),
            ),
          ),
        );
      }
    }

    if (widget.showMapControls) {
      widgets.add(
        Positioned(
          right: 12,
          bottom: widget.bottomInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _HeatmapToggle(
                active: widget.showNoiseZones,
                onTap: widget.onToggleNoiseZones,
              ),
              if (widget.showNoiseZones) ...<Widget>[
                const SizedBox(height: 8),
                const _NoiseLegend(),
              ],
              const SizedBox(height: 10),
              _LocateButton(onTap: _goToMyLocation),
            ],
          ),
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

  /// GeoJSON points for the IoT sound sensors, each carrying its live dB
  /// reading so the heatmap layers can show where the loud zones are.
  Map<String, dynamic> _noiseFeature(List<NoiseSensor> sensors) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        for (final sensor in sensors)
          <String, dynamic>{
            'type': 'Feature',
            'properties': <String, dynamic>{
              'id': sensor.id,
              'db': sensor.db,
              'zone': sensor.zone.name,
            },
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[
                sensor.position.longitude,
                sensor.position.latitude,
              ],
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

/// Live decibel badge shown over each IoT sound sensor on the noise heatmap.
///
/// The fill follows [NoiseZone], so a calm sensor reads blue, a moderate one
/// amber, and a loud one pulses red.
class _NoiseBadge extends StatelessWidget {
  const _NoiseBadge({super.key, required this.sensor});

  final NoiseSensor sensor;

  @override
  Widget build(BuildContext context) {
    final zone = sensor.zone;
    final label = '${sensor.db.round()} dB';

    return Semantics(
      label: 'Noise sensor ${sensor.label}: $label, ${zone.label}',
      child: _NoiseBadgeSurface(
        zone: zone,
        label: label,
        pulsing: zone.isDanger,
      ),
    );
  }
}

/// The badge pill itself. [pulsing] adds the red heartbeat that marks the
/// danger zone, so a loud walkway pulls the eye straight away.
class _NoiseBadgeSurface extends StatefulWidget {
  const _NoiseBadgeSurface({
    required this.zone,
    required this.label,
    required this.pulsing,
  });

  final NoiseZone zone;
  final String label;
  final bool pulsing;

  @override
  State<_NoiseBadgeSurface> createState() => _NoiseBadgeSurfaceState();
}

class _NoiseBadgeSurfaceState extends State<_NoiseBadgeSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _NoiseBadgeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulsing && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = widget.pulsing ? _pulse.value : 1.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: zone.darkColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: <BoxShadow>[
              // Only the danger zone glows, and it glows in its own colour.
              if (widget.pulsing)
                BoxShadow(
                  color: zone.color.withValues(alpha: 0.55 * t),
                  blurRadius: 4 + 10 * t,
                  spreadRadius: 1 + 3 * t,
                ),
              const BoxShadow(
                color: Color(0x55000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.graphic_eq, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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

/// Labelled toggle for the IoT sensory heatmap, written for neurodivergent
/// travellers: the headphone glyph plus plain language beats a bare icon.
class _HeatmapToggle extends StatelessWidget {
  const _HeatmapToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.primary;

    return Semantics(
      button: true,
      toggled: active,
      label: 'IoT sensory heatmap, neurodivergent mode',
      child: Tooltip(
        message: active
            ? 'Hide the IoT sensory heatmap'
            : 'Show the IoT sensory heatmap (neurodivergent mode)',
        child: Material(
          color: active ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 7, 13, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.headphones, size: 19, color: foreground),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'IoT Sensory Heatmap',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                      Text(
                        'Neurodivergent mode',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white.withValues(alpha: 0.72)
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colour key for the IoT sensory heatmap, shown while the layer is on.
class _NoiseLegend extends StatelessWidget {
  const _NoiseLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'AMBIENT NOISE',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          for (final zone in NoiseZone.values) _row(zone),
        ],
      ),
    );
  }

  Widget _row(NoiseZone zone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: zone.color,
              shape: BoxShape.circle,
              border: Border.all(color: zone.darkColor, width: 2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            zone.label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            zone.range,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
