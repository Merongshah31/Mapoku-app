import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Demo data for three Sime Darby Property hubs.
///
/// Coordinates, landmark names and walkway paths are the same ones used in
/// the team's MapLibre build (Merongshah31/Mapoku-app,
/// `sime_darby_demo_data.dart`), so both front ends tell the same story.
/// Distances are the real length of each path; minutes use a wheelchair pace
/// (0.9 m/s) for the OKU-safe route and a walking pace (1.3 m/s) for the
/// standard route.
class SimeDarbyDemo {
  const SimeDarbyDemo._();

  static final List<Township> townships = [_sjcc.township, _elmina.township, _klEast.township];

  static Township get defaultTownship => _sjcc.township;

  static _Hub _hub(String id) => switch (id) {
        'elmina' => _elmina,
        'kl_east' => _klEast,
        _ => _sjcc,
      };

  /// Builds a route plan for a township. [to] is what the user typed; the
  /// demo always routes to the hub's main destination.
  static RoutePlan plan(String townshipId, {DateTime? now}) {
    final h = _hub(townshipId);
    final t = now ?? DateTime.now();
    final obstacles = [
      for (var i = 0; i < h.obstacles.length; i++)
        Obstacle(
          id: '${h.township.id}_obs_$i',
          kind: h.obstacles[i].kind,
          title: h.obstacles[i].title,
          position: h.obstacles[i].at,
          reportedAt: t.subtract(h.obstacles[i].ago),
          confirmations: h.obstacles[i].confirmations,
        ),
    ];
    return RoutePlan(
      origin: h.township.start,
      requested: h.destination,
      obstacles: obstacles,
      stepFree: RouteOption(
        kind: RouteKind.stepFree,
        destination: h.destination,
        minutes: h.okuMinutes,
        meters: h.okuMeters,
        path: h.okuPath,
        obstacleIds: const [],
        steps: h.okuSteps,
        highlights: h.highlights,
      ),
      standard: RouteOption(
        kind: RouteKind.standard,
        destination: h.destination,
        minutes: h.stdMinutes,
        meters: h.stdMeters,
        path: h.stdPath,
        obstacleIds: obstacles.map((o) => o.id).toList(),
        steps: h.stdSteps,
      ),
    );
  }

  // ------------------------------------------------------------ SJCC / SJ7

  static final _sjcc = _Hub(
    township: Township(
      id: 'sjcc',
      name: 'SJCC / SJ7',
      location: 'Subang Jaya, Selangor',
      category: 'Transit-oriented development',
      center: LatLng(3.0833, 101.5878),
      start: Place(name: 'Subang Jaya LRT/KTM Station (SJ7)', area: 'Subang Jaya', position: LatLng(3.0845, 101.5861)),
      popular: [
        Place(name: 'SJCC Retail Hub, East Lobby', area: 'Subang Jaya', position: LatLng(3.0825, 101.5902)),
        Place(name: 'OKU Drop-off Zone', area: 'Subang Jaya', position: LatLng(3.0843, 101.5889)),
      ],
    ),
    destination: Place(name: 'SJCC Retail Hub, East Lobby', area: 'Subang Jaya', position: LatLng(3.0825, 101.5902)),
    okuPath: [
      LatLng(3.0845, 101.5861), LatLng(3.0849, 101.5866), LatLng(3.0851, 101.5871), LatLng(3.0852, 101.5874),
      LatLng(3.0849, 101.5880), LatLng(3.0846, 101.5885), LatLng(3.0843, 101.5889),
      LatLng(3.0836, 101.5895), LatLng(3.0831, 101.5899), LatLng(3.0825, 101.5902),
    ],
    okuMeters: 609,
    okuMinutes: 12,
    stdPath: [
      LatLng(3.0845, 101.5861), LatLng(3.0841, 101.5869), LatLng(3.0838, 101.5876), LatLng(3.0836, 101.5882),
      LatLng(3.0832, 101.5889), LatLng(3.0829, 101.5896), LatLng(3.0825, 101.5902),
    ],
    stdMeters: 508,
    stdMinutes: 7,
    highlights: const [
      'Accessible lift at the SJ7 LRT station',
      'Covered link bridge, sheltered from rain',
      'Passes the OKU drop-off zone',
      'No stairs or kerbs the whole way',
    ],
    okuSteps: const [
      RouteStep(turn: Turn.straight, instruction: 'Take the accessible lift at SJ7 up to the link bridge'),
      RouteStep(turn: Turn.right, instruction: 'Follow the covered link bridge for 150 m'),
      RouteStep(turn: Turn.straight, instruction: 'Continue past the OKU drop-off zone', caution: 'E-hailing cars sometimes stop here'),
      RouteStep(turn: Turn.right, instruction: 'Follow the walkway to the East Lobby for 200 m'),
      RouteStep(turn: Turn.arrive, instruction: 'Arrive at SJCC East Lobby, automatic doors ahead'),
    ],
    stdSteps: const [
      RouteStep(turn: Turn.straight, instruction: 'Head south-east along the station service road'),
      RouteStep(turn: Turn.straight, instruction: 'Cross at the level crossing', caution: 'No dropped kerb'),
      RouteStep(turn: Turn.left, instruction: 'Take the stairs up to the retail hub', caution: 'Stairs only, no ramp'),
      RouteStep(turn: Turn.arrive, instruction: 'Arrive at SJCC Retail Hub'),
    ],
    obstacles: const [
      _ObsSeed(ObstacleKind.noDroppedKerb, 'Level crossing at SJ7 has no dropped kerb', _P(3.0836, 101.5882), Duration(hours: 4), 11),
      _ObsSeed(ObstacleKind.noRamp, 'Stairs only up to the retail hub', _P(3.0831, 101.5891), Duration(days: 2), 17),
      _ObsSeed(ObstacleKind.unevenSurface, 'Broken paving on the service road', _P(3.0840, 101.5871), Duration(hours: 9), 4),
    ],
  );

  // ------------------------------------------------------------ City of Elmina

  static final _elmina = _Hub(
    township: Township(
      id: 'elmina',
      name: 'City of Elmina',
      location: 'Shah Alam, Selangor',
      category: 'Township',
      center: LatLng(3.1842, 101.5135),
      start: Place(name: 'Elmina Central Park Entrance', area: 'City of Elmina', position: LatLng(3.1835, 101.5118)),
      popular: [
        Place(name: 'Elmina Lakeside Mall', area: 'City of Elmina', position: LatLng(3.1851, 101.5152)),
        Place(name: 'Tactile Park Walkway', area: 'City of Elmina', position: LatLng(3.1844, 101.5129)),
      ],
    ),
    destination: Place(name: 'Elmina Lakeside Mall', area: 'City of Elmina', position: LatLng(3.1851, 101.5152)),
    okuPath: [
      LatLng(3.1835, 101.5118), LatLng(3.1839, 101.5122), LatLng(3.1842, 101.5126), LatLng(3.1844, 101.5129),
      LatLng(3.1848, 101.5133), LatLng(3.1852, 101.5137), LatLng(3.1855, 101.5140),
      LatLng(3.1854, 101.5144), LatLng(3.1853, 101.5148), LatLng(3.1851, 101.5152),
    ],
    okuMeters: 473,
    okuMinutes: 9,
    stdPath: [
      LatLng(3.1835, 101.5118), LatLng(3.1838, 101.5124), LatLng(3.1841, 101.5130), LatLng(3.1843, 101.5135),
      LatLng(3.1846, 101.5141), LatLng(3.1849, 101.5147), LatLng(3.1851, 101.5152),
    ],
    stdMeters: 418,
    stdMinutes: 6,
    highlights: const [
      'Covered walkway through Central Park',
      'Tactile paving for blind and low-vision visitors',
      'Gentle wheelchair ramp up to the mall',
      'Enters at the mall\'s accessible entrance',
    ],
    okuSteps: const [
      RouteStep(turn: Turn.straight, instruction: 'From the park entrance, follow the covered walkway for 120 m'),
      RouteStep(turn: Turn.left, instruction: 'Join the tactile walkway along the park', caution: 'Some tactile tiles are loose'),
      RouteStep(turn: Turn.right, instruction: 'Take the north wheelchair ramp towards the mall'),
      RouteStep(turn: Turn.arrive, instruction: 'Arrive at Lakeside Mall accessible entrance'),
    ],
    stdSteps: const [
      RouteStep(turn: Turn.straight, instruction: 'Follow the park service road east'),
      RouteStep(turn: Turn.straight, instruction: 'Cross the road at Elmina', caution: 'No dropped kerb'),
      RouteStep(turn: Turn.left, instruction: 'Take the stairs up to the mall forecourt', caution: 'Stairs only, no ramp'),
      RouteStep(turn: Turn.arrive, instruction: 'Arrive at Elmina Lakeside Mall'),
    ],
    obstacles: const [
      _ObsSeed(ObstacleKind.noDroppedKerb, 'Roadside crossing has no dropped kerb', _P(3.1843, 101.5135), Duration(hours: 6), 8),
      _ObsSeed(ObstacleKind.noRamp, 'Stairs only to the mall forecourt', _P(3.1847, 101.5143), Duration(days: 1), 13),
      _ObsSeed(ObstacleKind.flooding, 'Service road floods after heavy rain', _P(3.1839, 101.5126), Duration(hours: 20), 5),
    ],
  );

  // ------------------------------------------------------------ KL East

  static final _klEast = _Hub(
    township: Township(
      id: 'kl_east',
      name: 'KL East',
      location: 'Kuala Lumpur',
      category: 'Integrated development',
      center: LatLng(3.2248, 101.7294),
      start: Place(name: 'KL East Mall Main Drop-off', area: 'KL East', position: LatLng(3.2241, 101.7285)),
      popular: [
        Place(name: 'The Ridge & Park Residence', area: 'KL East', position: LatLng(3.2256, 101.7305)),
        Place(name: 'Step-Free Garden Promenade', area: 'KL East', position: LatLng(3.2250, 101.7290)),
      ],
    ),
    destination: Place(name: 'The Ridge & Park Residence', area: 'KL East', position: LatLng(3.2256, 101.7305)),
    okuPath: [
      LatLng(3.2241, 101.7285), LatLng(3.2245, 101.7287), LatLng(3.2248, 101.7289), LatLng(3.2250, 101.7290),
      LatLng(3.2252, 101.7293), LatLng(3.2252, 101.7296), LatLng(3.2253, 101.7298),
      LatLng(3.2254, 101.7300), LatLng(3.2255, 101.7303), LatLng(3.2256, 101.7305),
    ],
    okuMeters: 298,
    okuMinutes: 6,
    stdPath: [
      LatLng(3.2241, 101.7285), LatLng(3.2244, 101.7288), LatLng(3.2246, 101.7292), LatLng(3.2248, 101.7295),
      LatLng(3.2251, 101.7298), LatLng(3.2254, 101.7301), LatLng(3.2256, 101.7305),
    ],
    stdMeters: 281,
    stdMinutes: 4,
    highlights: const [
      'Step-free garden promenade',
      'Accessible pedestrian crossing with dropped kerbs',
      'Lift straight up to the residential lobby',
    ],
    okuSteps: const [
      RouteStep(turn: Turn.straight, instruction: 'From the mall drop-off, head to the garden promenade'),
      RouteStep(turn: Turn.right, instruction: 'Follow the step-free promenade for 120 m'),
      RouteStep(turn: Turn.straight, instruction: 'Use the accessible pedestrian crossing'),
      RouteStep(turn: Turn.arrive, instruction: 'Take the lobby lift to The Ridge & Park Residence'),
    ],
    stdSteps: const [
      RouteStep(turn: Turn.straight, instruction: 'Walk along the roadside footpath'),
      RouteStep(turn: Turn.straight, instruction: 'Cross the road at KL East', caution: 'No dropped kerb'),
      RouteStep(turn: Turn.left, instruction: 'Take the stairs up to the residence', caution: 'Stairs only, no ramp'),
      RouteStep(turn: Turn.arrive, instruction: 'Arrive at The Ridge & Park Residence'),
    ],
    obstacles: const [
      _ObsSeed(ObstacleKind.narrowPath, 'Roadside footpath narrowed by parked motorbikes', _P(3.2245, 101.7290), Duration(hours: 3), 6),
      _ObsSeed(ObstacleKind.noRamp, 'Stairs only up to the residence', _P(3.2252, 101.7299), Duration(days: 3), 9),
    ],
  );
}

/// Plain lat/lng pair so obstacle seeds can be `const`.
class _P {
  final double lat;
  final double lng;
  const _P(this.lat, this.lng);
}

class _ObsSeed {
  final ObstacleKind kind;
  final String title;
  final _P _at;
  final Duration ago;
  final int confirmations;
  const _ObsSeed(this.kind, this.title, this._at, this.ago, this.confirmations);

  LatLng get at => LatLng(_at.lat, _at.lng);
}

class _Hub {
  final Township township;
  final Place destination;
  final List<LatLng> okuPath;
  final int okuMeters;
  final int okuMinutes;
  final List<LatLng> stdPath;
  final int stdMeters;
  final int stdMinutes;
  final List<String> highlights;
  final List<RouteStep> okuSteps;
  final List<RouteStep> stdSteps;
  final List<_ObsSeed> obstacles;

  const _Hub({
    required this.township,
    required this.destination,
    required this.okuPath,
    required this.okuMeters,
    required this.okuMinutes,
    required this.stdPath,
    required this.stdMeters,
    required this.stdMinutes,
    required this.highlights,
    required this.okuSteps,
    required this.stdSteps,
    required this.obstacles,
  });
}
