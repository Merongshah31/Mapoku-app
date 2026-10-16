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

/// A real-world wayfinding node (POI) in the routing graph.
class HubNode {
  const HubNode({
    required this.id,
    required this.label,
    required this.position,
    required this.kind,
    this.icon = '📍',
    this.stepFree = true,
    this.covered = false,
  });

  final String id;
  final String label;

  /// Real GPS position (WGS84).
  final LatLng position;

  final NodeKind kind;
  final String icon;
  final bool stepFree;
  final bool covered;
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
  });

  final String from;
  final String to;

  /// 3–6 waypoints curving along the actual roads / walkways.
  final List<LatLng> geometry;

  final bool hasStairs;
  final bool covered;
  final String label;

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
