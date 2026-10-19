import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../models/obstacle.dart';
import '../models/sime_darby_hub.dart';
import 'accessible_pathfinder.dart';

/// How a community-reported obstacle relates to the route being shown.
enum HazardImpact {
  /// The route still passes it (no way round), so the user is warned.
  onRoute,

  /// The usual route went through it, so the route was bent around it.
  avoided,

  /// Reported on a walkway this route does not use.
  nearby,
}

/// A community-reported obstacle that sits on one of a hub's walkways.
class RouteHazard {
  const RouteHazard({
    required this.obstacle,
    required this.edge,
    this.impact = HazardImpact.nearby,
  });

  final Obstacle obstacle;
  final HubEdge edge;
  final HazardImpact impact;

  RouteHazard withImpact(HazardImpact value) =>
      RouteHazard(obstacle: obstacle, edge: edge, impact: value);
}

/// Turns community reports into closed walkways for the pathfinder.
///
/// A report counts when it is pinned within [reachMeters] of a walkway, and
/// it stops counting once more people say "it's gone" than "still there".
/// Wheelchair routing treats every report as blocking; a standard pedestrian
/// route only avoids paths that are fully blocked.
class RouteHazards {
  const RouteHazards._();

  static const double reachMeters = 30;

  static List<RouteHazard> forHub(
    SimeDarbyHub hub,
    Iterable<Obstacle> reports, {
    required bool accessible,
  }) {
    final hazards = <RouteHazard>[];

    for (final report in reports) {
      if (report.clearances > report.confirms) continue;
      if (!accessible && report.type != ObstacleType.pathBlocked) continue;

      HubEdge? nearest;
      var nearestDistance = reachMeters;
      for (final edge in hub.edges) {
        final distance = _distanceToPolylineMeters(
          report.position,
          edge.geometry,
        );
        if (distance <= nearestDistance) {
          nearest = edge;
          nearestDistance = distance;
        }
      }

      if (nearest != null) {
        hazards.add(RouteHazard(obstacle: report, edge: nearest));
      }
    }
    return hazards;
  }

  /// Labels each hazard against the route as it was and as it is now.
  static List<RouteHazard> assess(
    List<RouteHazard> hazards, {
    required PathResult usual,
    required PathResult active,
  }) {
    return [
      for (final hazard in hazards)
        hazard.withImpact(
          active.edges.contains(hazard.edge)
              ? HazardImpact.onRoute
              : usual.edges.contains(hazard.edge)
              ? HazardImpact.avoided
              : HazardImpact.nearby,
        ),
    ];
  }

  /// Shortest distance from [point] to a polyline, in metres, using a local
  /// flat projection (accurate to well under a metre at walkway scale).
  static double _distanceToPolylineMeters(LatLng point, List<LatLng> line) {
    if (line.isEmpty) return double.infinity;

    const metresPerDegree = 111320.0;
    final lngScale = math.cos(point.latitude * math.pi / 180) * metresPerDegree;

    (double, double) project(LatLng p) => (
      (p.longitude - point.longitude) * lngScale,
      (p.latitude - point.latitude) * metresPerDegree,
    );

    var best = double.infinity;
    for (var i = 0; i < line.length; i++) {
      final a = project(line[i]);
      final b = i + 1 < line.length ? project(line[i + 1]) : a;

      final dx = b.$1 - a.$1;
      final dy = b.$2 - a.$2;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : (-(a.$1 * dx + a.$2 * dy) / lengthSquared).clamp(0.0, 1.0);

      final cx = a.$1 + dx * t;
      final cy = a.$2 + dy * t;
      best = math.min(best, math.sqrt(cx * cx + cy * cy));
    }
    return best;
  }
}
