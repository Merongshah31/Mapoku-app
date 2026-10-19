import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapoku/features/sime_darby/data/sime_darby_demo_data.dart';
import 'package:mapoku/features/sime_darby/models/sime_darby_hub.dart';
import 'package:mapoku/features/sime_darby/services/accessible_pathfinder.dart';
import 'package:mapoku/features/sime_darby/services/route_hazards.dart';
import 'package:mapoku/models/obstacle.dart';

void main() {
  const pathfinder = AccessiblePathfinder();

  test('OKU route is fully step-free and avoids the stairs shortcut', () {
    final hub = SimeDarbyDemoData.elmina;

    final oku = pathfinder.findPath(hub: hub, accessibleOnly: true)!;
    final standard = pathfinder.findPath(hub: hub, accessibleOnly: false)!;

    // OKU mode must never route through stairs.
    expect(oku.stepFree, isTrue);
    expect(oku.accessibilityScore, 100);

    // It should use the accessible chain nodes.
    final okuIds = oku.nodes.map((node) => node.id).toList();
    expect(okuIds, contains('el-n2'));
    expect(okuIds, contains('el-n3'));
    expect(okuIds.first, hub.startNodeId);
    expect(okuIds.last, hub.endNodeId);

    // The standard route is shorter because it uses the stairs.
    expect(standard.hasStairs, isTrue);
    expect(standard.distanceMeters, lessThan(oku.distanceMeters));
    expect(standard.accessibilityScore, lessThan(100));
  });

  test('a walkway closed by a report reroutes the OKU path', () {
    final hub = SimeDarbyDemoData.elmina;

    final normal = pathfinder.findPath(hub: hub, accessibleOnly: true)!;
    final blocked = pathfinder.findPath(
      hub: hub,
      accessibleOnly: true,
      blockedEdges: {hub.simulatedEdge!},
    )!;

    // A different (still step-free) path is produced.
    expect(
      blocked.nodes.map((node) => node.id).toList(),
      isNot(equals(normal.nodes.map((node) => node.id).toList())),
    );
    expect(blocked.stepFree, isTrue);

    // The walkway between el-n2 and el-n3 is closed, so the path must skip
    // el-n3 entirely and reach the destination via the north detour.
    final blockedIds = blocked.nodes.map((node) => node.id).toList();
    expect(blockedIds, isNot(contains('el-n3')));
    expect(blockedIds, contains('el-n2'));
    expect(blockedIds, contains('el-n4'));
  });

  test('every Sime Darby hub yields a step-free OKU route', () {
    for (final hub in SimeDarbyDemoData.hubs) {
      final result = pathfinder.findPath(hub: hub, accessibleOnly: true);

      expect(result, isNotNull, reason: hub.name);
      expect(result!.stepFree, isTrue, reason: hub.name);
      expect(result.nodes.first.id, hub.startNodeId, reason: hub.name);
      expect(result.nodes.last.id, hub.endNodeId, reason: hub.name);
      expect(result.coveredPercent, greaterThan(0), reason: hub.name);
    }
  });

  test('distance formatting reads naturally', () {
    expect(AccessiblePathfinder.formatDistance(420), '420 m');
    expect(AccessiblePathfinder.formatDistance(1400), '1.4 km');
    expect(AccessiblePathfinder.formatMinutes(5), '5 min');
    expect(AccessiblePathfinder.formatMinutes(0), '1 min');
  });

  group('community reports', () {
    final hub = SimeDarbyDemoData.elmina;
    final edge = hub.simulatedEdge!;

    Obstacle report({
      ObstacleType type = ObstacleType.pathBlocked,
      int confirms = 3,
      int clearances = 0,
      LatLng? at,
    }) => Obstacle(
      id: 'r',
      type: type,
      position: at ?? polylineMidpoint(edge.geometry),
      confirms: confirms,
      clearances: clearances,
    );

    test('a report pinned on a walkway closes it', () {
      final hazards = RouteHazards.forHub(hub, [report()], accessible: true);
      expect(hazards, hasLength(1));
      expect(hazards.single.edge, same(edge));
    });

    test('a report far from every walkway is ignored', () {
      final far = report(at: const LatLng(3.0, 101.0));
      expect(RouteHazards.forHub(hub, [far], accessible: true), isEmpty);
    });

    test('a report people say is gone stops blocking', () {
      final gone = report(confirms: 1, clearances: 4);
      expect(RouteHazards.forHub(hub, [gone], accessible: true), isEmpty);
    });

    test('a broken lift does not block a standard walking route', () {
      final lift = report(type: ObstacleType.liftBroken);
      expect(RouteHazards.forHub(hub, [lift], accessible: true), hasLength(1));
      expect(RouteHazards.forHub(hub, [lift], accessible: false), isEmpty);
    });

    test('assess marks avoided and on-route obstacles', () {
      final hazards = RouteHazards.forHub(hub, [report()], accessible: true);
      final usual = pathfinder.findPath(hub: hub, accessibleOnly: true)!;
      final detour = pathfinder.findPath(
        hub: hub,
        accessibleOnly: true,
        blockedEdges: {edge},
      )!;

      final avoided = RouteHazards.assess(
        hazards,
        usual: usual,
        active: detour,
      );
      expect(avoided.single.impact, HazardImpact.avoided);

      final stuck = RouteHazards.assess(hazards, usual: usual, active: usual);
      expect(stuck.single.impact, HazardImpact.onRoute);
    });
  });
}
