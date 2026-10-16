import 'package:flutter_test/flutter_test.dart';
import 'package:mapoku/features/sime_darby/data/sime_darby_demo_data.dart';
import 'package:mapoku/features/sime_darby/services/accessible_pathfinder.dart';

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

  test('simulated construction reroutes the OKU path in real time', () {
    final hub = SimeDarbyDemoData.elmina;

    final normal = pathfinder.findPath(hub: hub, accessibleOnly: true)!;
    final blocked = pathfinder.findPath(
      hub: hub,
      accessibleOnly: true,
      obstacleActive: true,
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
}