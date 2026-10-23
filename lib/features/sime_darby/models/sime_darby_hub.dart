import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Shared geodesic calculator for real-world route geometry.
const Distance _geodesic = Distance();

/// Real-world length of a street-following polyline, in metres.
double polylineLengthMeters(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _geodesic.as(LengthUnit.Meter, points[i - 1], points[i]);
  }
  return total;
}

/// Point at the middle of a polyline, used for obstacle badges.
LatLng polylineMidpoint(List<LatLng> points) {
  if (points.isEmpty) return const LatLng(0, 0);
  if (points.length == 1) return points.first;
  final target = polylineLengthMeters(points) / 2;
  var travelled = 0.0;
  for (var i = 1; i < points.length; i++) {
    final segment = _geodesic.as(LengthUnit.Meter, points[i - 1], points[i]);
    if (travelled + segment >= target) {
      final t = segment == 0 ? 0.0 : (target - travelled) / segment;
      return LatLng(
        points[i - 1].latitude + (points[i].latitude - points[i - 1].latitude) * t,
        points[i - 1].longitude + (points[i].longitude - points[i - 1].longitude) * t,
      );
    }
    travelled += segment;
  }
  return points.last;
}

/// Category of a pedestrian / OKU wayfinding node.
enum NodeKind { bridge, walkway, ramp, lift, entrance, dropOff, crossing, promenade, lobby, station }

/// How loud a walkway is in practice, used to steer sound-sensitive people
/// (autistic / ADHD travellers) away from sensory overload.
enum NoiseLevel {
  quiet('Quiet', 45, 'Calm, under 50 dB'),
  moderate('Moderate', 60, 'Normal neighbourhood sound'),
  noisy('Noisy', 75, 'Busy road, crowd or machines'),
  veryNoisy('Very noisy', 90, 'Construction, traffic, alarms');

  const NoiseLevel(this.label, this.db, this.description);

  final String label;

  /// Representative sound pressure level in decibels.
  final int db;
  final String description;

  /// Loud enough to trigger sensory overload.
  bool get isLoud => this == noisy || this == veryNoisy;

  static NoiseLevel forDb(double db) {
    if (db >= 85) return NoiseLevel.veryNoisy;
    if (db >= 70) return NoiseLevel.noisy;
    if (db >= 55) return NoiseLevel.moderate;
    return NoiseLevel.quiet;
  }
}

/// The three colour bands painted by the IoT sensory heatmap, so a
/// neurodivergent traveller can read the whole noise landscape at a glance.
///
/// | Band | Reading | Colour |
/// | --- | --- | --- |
/// | calm | under 55 dB | soft blue / green |
/// | moderate | 55-75 dB | amber |
/// | danger | over 75 dB | pulsing red |
enum NoiseZone {
  calm('Calm zone', 'Under 55 dB', Color(0xFF38BDF8), Color(0xFF0E7490)),
  moderate('Moderate zone', '55-75 dB', Color(0xFFF59E0B), Color(0xFFB45309)),
  danger('Danger zone', 'Over 75 dB', Color(0xFFEF4444), Color(0xFFB91C1C));

  const NoiseZone(this.label, this.range, this.color, this.darkColor);

  /// Name shown in the on-map legend.
  final String label;

  /// Human readable decibel range shown in the on-map legend.
  final String range;

  /// Bright fill used by the heatmap halo, the core dot and the legend swatch.
  final Color color;

  /// Contrast safe partner used by the solid decibel badge over the map.
  final Color darkColor;

  /// True for the band that pulses, warning about sensory overload.
  bool get isDanger => this == NoiseZone.danger;

  /// Classifies a live decibel reading into its heatmap band.
  ///
  /// The 70-75 dB window stays amber: the overload zone the heatmap warns
  /// about only starts above 75 dB.
  static NoiseZone forDb(double db) {
    if (db > 75) return NoiseZone.danger;
    if (db >= 55) return NoiseZone.moderate;
    return NoiseZone.calm;
  }
}

/// How bright / glary a walkway is, used to steer light-sensitive people.
enum LightLevel {
  shaded('Shaded', 'Under cover or deep tree shade'),
  moderate('Moderate', 'Normal daylight, no direct glare'),
  bright('Bright', 'Open sunlight, glare on surfaces'),
  veryBright('Very bright', 'Direct midday sun, reflective paving');

  const LightLevel(this.label, this.description);

  final String label;
  final String description;

  /// Bright enough to be uncomfortable for light-sensitive travellers.
  bool get isHarsh => this == bright || this == veryBright;
}

/// A simulated IoT sound sensor feeding the noise heatmap.
///
/// In the pilot these are Arduino / ESP32 microphone nodes mounted on Sime
/// Darby Property walkways; for the demo the readings are baked into
/// SimeDarbyDemoData so the heatmap is always available offline.
class NoiseSensor {
  const NoiseSensor({
    required this.id,
    required this.position,
    required this.db,
    this.radiusMeters = 30,
    this.label = '',
  });

  final String id;
  final LatLng position;

  /// Latest live reading in decibels.
  final double db;

  /// Approximate radius of the affected zone on the map, in metres.
  final double radiusMeters;
  final String label;

  NoiseLevel get level => NoiseLevel.forDb(db);

  /// Heatmap colour band for this sensor's latest reading.
  NoiseZone get zone => NoiseZone.forDb(db);
}

/// A real-world wayfinding node (POI) in the routing graph.
class HubNode {
  const HubNode({
    required this.id,
    required this.label,
    required this.position,
    required this.kind,
    this.stepFree = true,
    this.covered = false,
  });

  final String id;
  final String label;

  /// Real GPS position (WGS84).
  final LatLng position;

  final NodeKind kind;
  final bool stepFree;
  final bool covered;

  /// Icon for this kind of wayfinding point.
  IconData get iconData => switch (kind) {
    NodeKind.bridge => Icons.linear_scale,
    NodeKind.walkway => Icons.directions_walk,
    NodeKind.ramp => Icons.ramp_right,
    NodeKind.lift => Icons.elevator,
    NodeKind.entrance => Icons.meeting_room_outlined,
    NodeKind.dropOff => Icons.airport_shuttle,
    NodeKind.crossing => Icons.traffic,
    NodeKind.promenade => Icons.park_outlined,
    NodeKind.lobby => Icons.apartment,
    NodeKind.station => Icons.directions_transit,
  };
}

/// A walkable connection between two nodes, carrying the dense
/// street-following geometry that is drawn on the map as a 3D route.
class HubEdge {
  const HubEdge({
    required this.from,
    required this.to,
    required this.geometry,
    this.hasStairs = false,
    this.covered = false,
    this.label = '',
    this.noiseLevel = NoiseLevel.moderate,
    this.lightLevel = LightLevel.moderate,
    this.hasTactilePaving = false,
    this.buggyAccessible = true,
    this.widthMeters = 2.0,
  });

  final String from;
  final String to;

  /// 3–6 waypoints curving along the actual roads / walkways.
  final List<LatLng> geometry;

  final bool hasStairs;
  final bool covered;
  final String label;

  /// Sensory load along this walkway, from the IoT sound sensors.
  final NoiseLevel noiseLevel;

  /// How bright / glary this walkway is through the day.
  final LightLevel lightLevel;

  /// Tactile paving for white-cane users.
  final bool hasTactilePaving;

  /// Wide and step-free enough for the mapOKU buggy service.
  final bool buggyAccessible;

  /// Usable width of the walkway in metres.
  final double widthMeters;

  /// True when this walkway is calm enough for sound-sensitive travellers.
  bool get sensoryCalm => !noiseLevel.isLoud;

  /// Real length of the drawn polyline, in metres.
  double get lengthMeters => polylineLengthMeters(geometry);

  /// True when this edge connects [a] and [b] in either direction.
  bool links(String a, String b) => (from == a && to == b) || (from == b && to == a);

  /// Geometry oriented so it runs from [originId] towards the other node.
  List<LatLng> geometryFrom(String originId) =>
      from == originId ? geometry : geometry.reversed.toList();
}

/// A Sime Darby Property demo hub with real coordinates and a pedestrian graph.
class SimeDarbyHub {
  const SimeDarbyHub({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    required this.sizeLabel,
    required this.focusArea,
    required this.center,
    required this.pinALabel,
    required this.pinBLabel,
    required this.startNodeId,
    required this.endNodeId,
    required this.simulationEdge,
    required this.simulationLabel,
    required this.nodes,
    required this.edges,
    this.noiseSensors = const <NoiseSensor>[],
    this.zoom = 17.0,
    this.bearing = -20.0,
    this.pitch = 60.0,
  });

  final String id;
  final String name;
  final String state;
  final String category;
  final String sizeLabel;
  final String focusArea;

  /// Real-world camera target for the fly-to animation.
  final LatLng center;

  final String pinALabel;
  final String pinBLabel;

  final String startNodeId;
  final String endNodeId;

  /// The edge removed by the "simulate construction" demo control.
  final List<String> simulationEdge;
  final String simulationLabel;

  final List<HubNode> nodes;
  final List<HubEdge> edges;

  /// IoT sound sensors mapped on this hub, feeding the noise heatmap.
  final List<NoiseSensor> noiseSensors;

  final double zoom;
  final double bearing;
  final double pitch;

  String get subtitle => '$state · $category';
  String get metricsSubtitle => '$sizeLabel · $category';

  /// Real GPS position of Pin A.
  LatLng get pinA => nodeById(startNodeId).position;

  /// Real GPS position of Pin B.
  LatLng get pinB => nodeById(endNodeId).position;

  HubNode nodeById(String id) => nodes.firstWhere((node) => node.id == id);

  /// The closed edge used by the construction simulation, if any.
  HubEdge? get simulatedEdge {
    if (simulationEdge.length != 2) return null;
    for (final edge in edges) {
      if (edge.links(simulationEdge[0], simulationEdge[1])) return edge;
    }
    return null;
  }
}