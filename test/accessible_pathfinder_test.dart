import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapoku/features/sime_darby/data/sime_darby_demo_data.dart';
import 'package:mapoku/features/sime_darby/models/sime_darby_hub.dart';
import 'package:mapoku/features/sime_darby/services/accessible_pathfinder.dart';
import 'package:mapoku/features/sime_darby/services/route_hazards.dart';
import 'package:mapoku/features/sime_darby/widgets/route_search_panel.dart';
import 'package:mapoku/data/demo_data.dart';
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

  test('demo reports leave a way through at every site, in both modes', () {
    for (final hub in SimeDarbyDemoData.hubs) {
      for (final accessible in [true, false]) {
        final hazards = RouteHazards.forHub(
          hub,
          DemoData.communityObstacles,
          accessible: accessible,
        );
        final route = pathfinder.findPath(
          hub: hub,
          accessibleOnly: accessible,
          blockedEdges: {for (final h in hazards) h.edge},
        );
        expect(route, isNotNull, reason: '${hub.name} accessible=$accessible');
      }
    }
  });

  test('every demo report is pinned at one of the three sites', () {
    for (final report in DemoData.communityObstacles) {
      expect(
        SimeDarbyDemoData.hubs.any((hub) => report.location.endsWith(hub.name)),
        isTrue,
        reason: report.location,
      );
    }
  });

  group('sensory routing profiles', () {
    test('sound-sensitive routing avoids the noisy station service road', () {
      final hub = SimeDarbyDemoData.sjcc;
      final route = pathfinder.findPath(
        hub: hub,
        accessibleOnly: false,
        profile: const RouteProfile(avoidNoise: true),
      )!;

      expect(route.sensorySafe, isTrue);
      expect(route.worstNoise.isLoud, isFalse);
      expect(route.nodes.map((node) => node.id), isNot(contains('sj-s1')));
    });

    test('light-sensitive routing stays out of direct sun and glare', () {
      final hub = SimeDarbyDemoData.sjcc;
      final route = pathfinder.findPath(
        hub: hub,
        accessibleOnly: false,
        profile: const RouteProfile(avoidBright: true),
      )!;

      expect(route.worstLight.isHarsh, isFalse);
    });

    test('white-cane routing prefers tactile paving end to end', () {
      final hub = SimeDarbyDemoData.sjcc;
      final route = pathfinder.findPath(
        hub: hub,
        accessibleOnly: true,
        profile: const RouteProfile(stepFree: true, needsTactile: true),
      )!;

      expect(route.stepFree, isTrue);
      expect(route.tactilePercent, 100);
    });

    test('the buggy service reaches every hub on a step-free route', () {
      for (final hub in SimeDarbyDemoData.hubs) {
        final route = pathfinder.findPath(
          hub: hub,
          accessibleOnly: true,
          profile: const RouteProfile(stepFree: true, needsBuggy: true),
        );

        expect(route, isNotNull, reason: hub.name);
        expect(route!.stepFree, isTrue, reason: hub.name);
        expect(route.buggyFriendly, isTrue, reason: hub.name);
      }
    });

    test('every hub carries a loud IoT sensor for the red noise zones', () {
      for (final hub in SimeDarbyDemoData.hubs) {
        expect(hub.noiseSensors, isNotEmpty, reason: hub.name);
        expect(
          hub.noiseSensors.any((sensor) => sensor.level.isLoud),
          isTrue,
          reason: hub.name,
        );
        for (final sensor in hub.noiseSensors) {
          expect(sensor.db, greaterThan(0), reason: hub.name);
          expect(sensor.radiusMeters, greaterThan(0), reason: hub.name);
        }
      }
    });
  });

  group('IoT sensory heatmap zones', () {
    test('decibel readings fall into the three legend bands', () {
      expect(NoiseZone.forDb(42), NoiseZone.calm);
      expect(NoiseZone.forDb(54.9), NoiseZone.calm);
      expect(NoiseZone.forDb(55), NoiseZone.moderate);
      expect(NoiseZone.forDb(70), NoiseZone.moderate);
      // The 70-75 dB window stays amber; overload only starts above 75 dB.
      expect(NoiseZone.forDb(75), NoiseZone.moderate);
      expect(NoiseZone.forDb(75.1), NoiseZone.danger);
      expect(NoiseZone.forDb(92), NoiseZone.danger);
    });

    test('only the danger band asks for the pulsing red ring', () {
      expect(NoiseZone.calm.isDanger, isFalse);
      expect(NoiseZone.moderate.isDanger, isFalse);
      expect(NoiseZone.danger.isDanger, isTrue);
      expect(NoiseZone.danger.color.toARGB32(), 0xFFEF4444);
      expect(NoiseZone.calm.color.toARGB32(), 0xFF38BDF8);
      expect(NoiseZone.moderate.color.toARGB32(), 0xFFF59E0B);
    });

    test('the legend lists the requested bands in order', () {
      expect(NoiseZone.values, hasLength(3));
      expect(
        NoiseZone.values.map((zone) => zone.range).toList(),
        <String>['Under 55 dB', '55-75 dB', 'Over 75 dB'],
      );
    });

    test('a sensor reports the zone of its own reading', () {
      const sensor = NoiseSensor(
        id: 'test-a1',
        position: LatLng(3.0, 101.0),
        db: 78,
        label: 'Test crossing',
      );

      expect(sensor.zone, NoiseZone.danger);
      expect(sensor.zone.range, 'Over 75 dB');
    });

    test('every hub shows all three heatmap zones for the demo', () {
      for (final hub in SimeDarbyDemoData.hubs) {
        final zones = hub.noiseSensors.map((sensor) => sensor.zone).toSet();

        expect(zones, contains(NoiseZone.calm), reason: hub.name);
        expect(zones, contains(NoiseZone.moderate), reason: hub.name);
        expect(zones, contains(NoiseZone.danger), reason: hub.name);
      }
    });

    test('the loud sensors that pulse are the danger-zone ones', () {
      for (final hub in SimeDarbyDemoData.hubs) {
        final loud = hub.noiseSensors.where((sensor) => sensor.zone.isDanger);

        expect(loud, isNotEmpty, reason: hub.name);
        for (final sensor in loud) {
          expect(sensor.db, greaterThan(75), reason: hub.name);
        }
      }
    });
  });

  group('accessibility needs map to routing profiles', () {
    test('each need builds the matching constraints', () {
      expect(AccessibilityNeed.wheelchair.profile.stepFree, isTrue);
      expect(AccessibilityNeed.soundSensitive.profile.avoidNoise, isTrue);
      expect(AccessibilityNeed.soundSensitive.profile.stepFree, isFalse);
      expect(AccessibilityNeed.lightSensitive.profile.avoidBright, isTrue);
      expect(AccessibilityNeed.blindLowVision.profile.needsTactile, isTrue);
      expect(AccessibilityNeed.blindLowVision.profile.stepFree, isTrue);
      expect(AccessibilityNeed.buggy.profile.needsBuggy, isTrue);
      expect(AccessibilityNeed.buggy.profile.stepFree, isTrue);
      expect(AccessibilityNeed.standard.isAccessible, isFalse);
      expect(AccessibilityNeed.standard.profile.stepFree, isFalse);
    });
  });
}
