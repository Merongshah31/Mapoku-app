import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/sime_darby_hub.dart';

/// The result of an A* search over a hub's real-world pedestrian graph.
class PathResult {
  const PathResult({
    required this.nodes,
    required this.polyline,
    required this.distanceMeters,
    required this.coveredMeters,
    required this.hasStairs,
  });

  /// The wayfinding nodes the route visits, in order.
  final List<HubNode> nodes;

  /// Street-following geometry drawn on the map as the 3D route.
  final List<LatLng> polyline;

  /// Real geodesic length of [polyline].
  final double distanceMeters;

  /// How much of that length is covered / weather-protected.
  final double coveredMeters;

  final bool hasStairs;

  /// Average walking pace for a pedestrian using an accessible route.
  static const double _metresPerMinute = 72;

  double get walkMinutes => distanceMeters <= 0 ? 0 : distanceMeters / _metresPerMinute;

  double get coveredPercent =>
      distanceMeters <= 0 ? 0 : (coveredMeters / distanceMeters * 100).clamp(0, 100);

  /// 100% when the route is fully step-free, otherwise a reduced score.
  int get accessibilityScore => hasStairs ? 62 : 100;

  bool get stepFree => !hasStairs;
}

/// A* pathfinding tuned for OKU / wheelchair wayfinding over real coordinates.
///
/// In accessible mode stairs are treated as impassable and covered walkways
/// receive a small cost bonus. In standard mode the shortest path wins, which
/// is what makes the standard route "pass the stairs" in the demo. Every edge
/// carries its own street-following geometry, so the winning path draws as a
/// real street-aligned route.
class AccessiblePathfinder {
  const AccessiblePathfinder();

  PathResult? findPath({
    required SimeDarbyHub hub,
    required bool accessibleOnly,
    bool obstacleActive = false,
  }) {
    final nodes = {for (final node in hub.nodes) node.id: node};
    final start = hub.startNodeId;
    final goal = hub.endNodeId;

    if (!nodes.containsKey(start) || !nodes.containsKey(goal)) return null;

    final adjacency = <String, List<HubEdge>>{};
    for (final edge in hub.edges) {
      if (obstacleActive && _isSimulationEdge(hub, edge)) continue;
      adjacency.putIfAbsent(edge.from, () => <HubEdge>[]).add(edge);
      adjacency.putIfAbsent(edge.to, () => <HubEdge>[]).add(edge);
    }

    // The authored edge weights are not proportional to the geometric distance
    // between nodes, so a plain euclidean heuristic would overestimate and make
    // A* suboptimal. Deriving the cheapest "cost per metre" across usable edges
    // keeps the straight-line estimate a true lower bound.
    final heuristicScale = _heuristicScale(nodes, adjacency, accessibleOnly);

    final gScore = <String, double>{start: 0};
    final cameFrom = <String, (String, HubEdge)>{};
    final open = <String>[start];
    final closed = <String>{};

    while (open.isNotEmpty) {
      open.sort((a, b) => _f(a, gScore, nodes, goal, heuristicScale)
          .compareTo(_f(b, gScore, nodes, goal, heuristicScale)));
      final current = open.removeAt(0);

      if (current == goal) return _reconstruct(cameFrom, nodes, start, goal);

      closed.add(current);

      for (final edge in adjacency[current] ?? const <HubEdge>[]) {
        final next = edge.from == current ? edge.to : edge.from;
        if (closed.contains(next)) continue;

        final stepCost = _edgeCost(edge, accessibleOnly);
        if (stepCost.isInfinite) continue;

        final tentative = (gScore[current] ?? double.infinity) + stepCost;
        if (tentative < (gScore[next] ?? double.infinity)) {
          gScore[next] = tentative;
          cameFrom[next] = (current, edge);
          if (!open.contains(next)) open.add(next);
        }
      }
    }

    return null;
  }

  /// Lowest cost-per-metre across the usable edges, used as an admissible
  /// heuristic multiplier.
  double _heuristicScale(
    Map<String, HubNode> nodes,
    Map<String, List<HubEdge>> adjacency,
    bool accessibleOnly,
  ) {
    var scale = double.infinity;
    for (final edges in adjacency.values) {
      for (final edge in edges) {
        final cost = _edgeCost(edge, accessibleOnly);
        if (!cost.isFinite) continue;
        final from = nodes[edge.from];
        final to = nodes[edge.to];
        if (from == null || to == null) continue;
        final length = polylineLengthMeters(<LatLng>[from.position, to.position]);
        if (length <= 0) continue;
        final ratio = cost / length;
        if (ratio < scale) scale = ratio;
      }
    }
    return scale.isFinite ? scale : 0;
  }

  double _f(
    String id,
    Map<String, double> g,
    Map<String, HubNode> nodes,
    String goal,
    double heuristicScale,
  ) {
    final node = nodes[id];
    final target = nodes[goal];
    if (node == null || target == null) return double.infinity;
    final heuristic =
        polylineLengthMeters(<LatLng>[node.position, target.position]) * heuristicScale;
    return (g[id] ?? double.infinity) + heuristic;
  }

  double _edgeCost(HubEdge edge, bool accessibleOnly) {
    if (accessibleOnly) {
      // Wheelchair users simply cannot use stairs.
      if (edge.hasStairs) return double.infinity;
      // Prefer covered, weather-protected walkways.
      return edge.covered ? edge.lengthMeters * 0.9 : edge.lengthMeters;
    }
    return edge.lengthMeters;
  }

  bool _isSimulationEdge(SimeDarbyHub hub, HubEdge edge) {
    if (hub.simulationEdge.length != 2) return false;
    return edge.links(hub.simulationEdge[0], hub.simulationEdge[1]);
  }

  /// Rebuilds the winning path and concatenates each edge's real geometry so
  /// the drawn route follows the streets instead of cutting diagonals.
  PathResult _reconstruct(
    Map<String, (String, HubEdge)> cameFrom,
    Map<String, HubNode> nodes,
    String start,
    String goal,
  ) {
    final orderedIds = <String>[goal];
    var cursor = goal;

    while (cursor != start && cameFrom.containsKey(cursor)) {
      final (previous, edge) = cameFrom[cursor]!;
      orderedIds.add(previous);
      cursor = previous;
    }

    final ids = orderedIds.reversed.toList();
    final polyline = <LatLng>[];
    var distance = 0.0;
    var covered = 0.0;
    var stairs = false;

    for (var i = 1; i < ids.length; i++) {
      final fromId = ids[i - 1];
      final step = cameFrom[ids[i]];
      if (step == null) continue;
      final edge = step.$2;

      for (final point in edge.geometryFrom(fromId)) {
        if (polyline.isEmpty || polyline.last != point) polyline.add(point);
      }

      distance += edge.lengthMeters;
      if (edge.covered) covered += edge.lengthMeters;
      if (edge.hasStairs) stairs = true;
    }

    return PathResult(
      nodes: <HubNode>[for (final id in ids) nodes[id]!],
      polyline: polyline,
      distanceMeters: distance,
      coveredMeters: covered,
      hasStairs: stairs,
    );
  }

  /// Formats `420 m` / `1.4 km`.
  static String formatDistance(double metres) {
    if (metres >= 1000) return '${(metres / 1000).toStringAsFixed(1)} km';
    return '${metres.round()} m';
  }

  /// Formats the walk duration as `6 min`.
  static String formatMinutes(double minutes) {
    final rounded = math.max(1, minutes.round());
    return '$rounded min';
  }
}
