import 'package:latlong2/latlong.dart';

import '../models/sime_darby_hub.dart';

/// Real-world 3D demo data for the three Sime Darby Property hubs.
///
/// Every coordinate is a real WGS84 position in Malaysia, and every routing
/// edge carries a dense street-following polyline (3-6 waypoints) so the drawn
/// routes curve along actual roads and pedestrian walkways instead of running
/// as straight diagonals.
class SimeDarbyDemoData {
  const SimeDarbyDemoData._();

  /// OpenFreeMap "bright" vector style - free, no API key required.
  static const String styleUrl = 'https://tiles.openfreemap.org/styles/bright';

  /// Existing vector source inside that style, used for the 3D buildings.
  static const String buildingSourceId = 'openmaptiles';
  static const String buildingSourceLayer = 'building';

  static const List<SimeDarbyHub> hubs = <SimeDarbyHub>[sjcc, elmina, klEast];

  // ---------------------------------------------------------------------------
  // 1. SJCC / SJ7 - Integrated Transit-Oriented Development
  // ---------------------------------------------------------------------------

  static const SimeDarbyHub sjcc = SimeDarbyHub(
    id: 'sjcc',
    name: 'SJCC / SJ7',
    state: 'Selangor',
    category: 'Integrated Transit-Oriented Development',
    sizeLabel: '30 Acres',
    focusArea: 'Subang Jaya LRT/KTM Station to SJCC Retail Hub',
    center: LatLng(3.0833, 101.5878),
    pinALabel: 'Subang Jaya LRT/KTM Station (SJ7)',
    pinBLabel: 'SJCC Retail Hub / East Lobby',
    startNodeId: 'sj-n1',
    endNodeId: 'sj-n4',
    simulationEdge: <String>['sj-n2', 'sj-n3'],
    simulationLabel: 'Elevated link bridge section closed for works',
    noiseSensors: <NoiseSensor>[
      NoiseSensor(
        id: 'sj-a1',
        position: LatLng(3.0838, 101.5879),
        db: 88,
        radiusMeters: 45,
        label: 'SJ7 station service road',
      ),
      NoiseSensor(
        id: 'sj-a2',
        position: LatLng(3.0836, 101.5882),
        db: 92,
        radiusMeters: 40,
        label: 'Level crossing at SJ7',
      ),
      NoiseSensor(
        id: 'sj-a3',
        position: LatLng(3.0847, 101.5867),
        db: 68,
        radiusMeters: 35,
        label: 'Covered link bridge ramp',
      ),
      NoiseSensor(
        id: 'sj-a4',
        position: LatLng(3.0834, 101.5894),
        db: 52,
        radiusMeters: 40,
        label: 'SJCC East Lobby plaza',
      ),
    ],
    nodes: <HubNode>[
      HubNode(
        id: 'sj-n1',
        label: 'SJ7 LRT Accessible Lift',
        position: LatLng(3.0845, 101.5861),
        kind: NodeKind.lift,
        covered: true,
      ),
      HubNode(
        id: 'sj-n2',
        label: 'Covered Link Bridge',
        position: LatLng(3.0852, 101.5874),
        kind: NodeKind.bridge,
        covered: true,
      ),
      HubNode(
        id: 'sj-n3',
        label: 'OKU Drop-off Zone',
        position: LatLng(3.0843, 101.5889),
        kind: NodeKind.dropOff,
        covered: true,
      ),
      HubNode(
        id: 'sj-n4',
        label: 'SJCC East Lobby',
        position: LatLng(3.0825, 101.5902),
        kind: NodeKind.lobby,
        covered: true,
      ),
      HubNode(
        id: 'sj-s1',
        label: 'Level Crossing at SJ7',
        position: LatLng(3.0836, 101.5882),
        kind: NodeKind.crossing,
        stepFree: false,
      ),
    ],
    edges: <HubEdge>[
      HubEdge(
        from: 'sj-n1',
        to: 'sj-n2',
        covered: true,
        noiseLevel: NoiseLevel.quiet,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 1.6,
        label: 'Accessible lift to link bridge',
        geometry: <LatLng>[
          LatLng(3.0845, 101.5861),
          LatLng(3.0849, 101.5866),
          LatLng(3.0851, 101.5871),
          LatLng(3.0852, 101.5874),
        ],
      ),
      HubEdge(
        from: 'sj-n2',
        to: 'sj-n3',
        covered: true,
        noiseLevel: NoiseLevel.moderate,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 1.8,
        label: 'Covered elevated bridge',
        geometry: <LatLng>[
          LatLng(3.0852, 101.5874),
          LatLng(3.0849, 101.5880),
          LatLng(3.0846, 101.5885),
          LatLng(3.0843, 101.5889),
        ],
      ),
      HubEdge(
        from: 'sj-n3',
        to: 'sj-n4',
        covered: true,
        noiseLevel: NoiseLevel.moderate,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 2.6,
        label: 'Drop-off to East Lobby',
        geometry: <LatLng>[
          LatLng(3.0843, 101.5889),
          LatLng(3.0836, 101.5895),
          LatLng(3.0831, 101.5899),
          LatLng(3.0825, 101.5902),
        ],
      ),
      HubEdge(
        from: 'sj-n1',
        to: 'sj-s1',
        noiseLevel: NoiseLevel.veryNoisy,
        lightLevel: LightLevel.veryBright,
        hasTactilePaving: false,
        buggyAccessible: false,
        widthMeters: 1.4,
        label: 'Station service road',
        geometry: <LatLng>[
          LatLng(3.0845, 101.5861),
          LatLng(3.0841, 101.5869),
          LatLng(3.0838, 101.5876),
          LatLng(3.0836, 101.5882),
        ],
      ),
      HubEdge(
        from: 'sj-s1',
        to: 'sj-n4',
        hasStairs: true,
        noiseLevel: NoiseLevel.noisy,
        lightLevel: LightLevel.bright,
        hasTactilePaving: false,
        buggyAccessible: false,
        widthMeters: 1.2,
        label: 'Stairs to retail hub',
        geometry: <LatLng>[
          LatLng(3.0836, 101.5882),
          LatLng(3.0832, 101.5889),
          LatLng(3.0829, 101.5896),
          LatLng(3.0825, 101.5902),
        ],
      ),
      HubEdge(
        from: 'sj-n2',
        to: 'sj-n4',
        covered: true,
        noiseLevel: NoiseLevel.quiet,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 2.4,
        label: 'South covered detour',
        geometry: <LatLng>[
          LatLng(3.0852, 101.5874),
          LatLng(3.0850, 101.5886),
          LatLng(3.0845, 101.5898),
          LatLng(3.0838, 101.5906),
          LatLng(3.0825, 101.5902),
        ],
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // 2. City of Elmina - Township
  // ---------------------------------------------------------------------------

  static const SimeDarbyHub elmina = SimeDarbyHub(
    id: 'elmina',
    name: 'City of Elmina',
    state: 'Selangor',
    category: 'Township',
    sizeLabel: '5,000 Acres',
    focusArea: 'Elmina Central Park to Elmina Lakeside Mall',
    center: LatLng(3.1842, 101.5135),
    pinALabel: 'Elmina Central Park Entrance',
    pinBLabel: 'Elmina Lakeside Mall',
    startNodeId: 'el-n1',
    endNodeId: 'el-n4',
    simulationEdge: <String>['el-n2', 'el-n3'],
    simulationLabel: 'Tactile Park Walkway closed for works',
    noiseSensors: <NoiseSensor>[
      NoiseSensor(
        id: 'el-a1',
        position: LatLng(3.1840, 101.5128),
        db: 86,
        radiusMeters: 45,
        label: 'Elmina park service road',
      ),
      NoiseSensor(
        id: 'el-a2',
        position: LatLng(3.1843, 101.5135),
        // Amber band: a moderately busy crossing beside the quiet park
        // walkway, so this hub shows all three heatmap zones.
        db: 66,
        radiusMeters: 40,
        label: 'Roadside crossing at Elmina',
      ),
      NoiseSensor(
        id: 'el-a3',
        position: LatLng(3.1844, 101.5129),
        db: 48,
        radiusMeters: 40,
        label: 'Tactile park walkway',
      ),
      NoiseSensor(
        id: 'el-a4',
        position: LatLng(3.1855, 101.5140),
        db: 44,
        radiusMeters: 35,
        label: 'Wheelchair ramp north',
      ),
    ],
    nodes: <HubNode>[
      HubNode(
        id: 'el-n1',
        label: 'Elmina Central Park Entrance',
        position: LatLng(3.1835, 101.5118),
        kind: NodeKind.entrance,
      ),
      HubNode(
        id: 'el-n2',
        label: 'Tactile Park Walkway',
        position: LatLng(3.1844, 101.5129),
        kind: NodeKind.walkway,
      ),
      HubNode(
        id: 'el-n3',
        label: 'Wheelchair Ramp North',
        position: LatLng(3.1855, 101.5140),
        kind: NodeKind.ramp,
      ),
      HubNode(
        id: 'el-n4',
        label: 'Lakeside Mall Accessible Entrance',
        position: LatLng(3.1851, 101.5152),
        kind: NodeKind.entrance,
        covered: true,
      ),
      HubNode(
        id: 'el-s1',
        label: 'Roadside Crossing at Elmina',
        position: LatLng(3.1843, 101.5135),
        kind: NodeKind.crossing,
        stepFree: false,
      ),
    ],
    edges: <HubEdge>[
      HubEdge(
        from: 'el-n1',
        to: 'el-n2',
        covered: true,
        noiseLevel: NoiseLevel.quiet,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 2.6,
        label: 'Covered park walkway',
        geometry: <LatLng>[
          LatLng(3.1835, 101.5118),
          LatLng(3.1839, 101.5122),
          LatLng(3.1842, 101.5126),
          LatLng(3.1844, 101.5129),
        ],
      ),
      HubEdge(
        from: 'el-n2',
        to: 'el-n3',
        noiseLevel: NoiseLevel.moderate,
        lightLevel: LightLevel.moderate,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 2.4,
        label: 'Tactile park walkway',
        geometry: <LatLng>[
          LatLng(3.1844, 101.5129),
          LatLng(3.1848, 101.5133),
          LatLng(3.1852, 101.5137),
          LatLng(3.1855, 101.5140),
        ],
      ),
      HubEdge(
        from: 'el-n3',
        to: 'el-n4',
        covered: true,
        noiseLevel: NoiseLevel.moderate,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 2.2,
        label: 'Wheelchair ramp to mall entrance',
        geometry: <LatLng>[
          LatLng(3.1855, 101.5140),
          LatLng(3.1854, 101.5144),
          LatLng(3.1853, 101.5148),
          LatLng(3.1851, 101.5152),
        ],
      ),
      HubEdge(
        from: 'el-n1',
        to: 'el-s1',
        noiseLevel: NoiseLevel.veryNoisy,
        lightLevel: LightLevel.veryBright,
        hasTactilePaving: false,
        buggyAccessible: false,
        widthMeters: 1.5,
        label: 'Park service road',
        geometry: <LatLng>[
          LatLng(3.1835, 101.5118),
          LatLng(3.1838, 101.5124),
          LatLng(3.1841, 101.5130),
          LatLng(3.1843, 101.5135),
        ],
      ),
      HubEdge(
        from: 'el-s1',
        to: 'el-n4',
        hasStairs: true,
        noiseLevel: NoiseLevel.noisy,
        lightLevel: LightLevel.bright,
        hasTactilePaving: false,
        buggyAccessible: false,
        widthMeters: 1.2,
        label: 'Stairs to mall forecourt',
        geometry: <LatLng>[
          LatLng(3.1843, 101.5135),
          LatLng(3.1846, 101.5141),
          LatLng(3.1849, 101.5147),
          LatLng(3.1851, 101.5152),
        ],
      ),
      HubEdge(
        from: 'el-n2',
        to: 'el-n4',
        covered: true,
        noiseLevel: NoiseLevel.quiet,
        lightLevel: LightLevel.moderate,
        hasTactilePaving: false,
        buggyAccessible: true,
        widthMeters: 2.8,
        label: 'Lakeside north detour',
        geometry: <LatLng>[
          LatLng(3.1844, 101.5129),
          LatLng(3.1860, 101.5135),
          LatLng(3.1858, 101.5146),
          LatLng(3.1851, 101.5152),
        ],
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // 3. KL East - Integrated Development
  // ---------------------------------------------------------------------------

  static const SimeDarbyHub klEast = SimeDarbyHub(
    id: 'kl-east',
    name: 'KL East',
    state: 'Kuala Lumpur',
    category: 'Integrated Development',
    sizeLabel: '154 Acres',
    focusArea: 'KL East Mall to The Ridge & Park Residence',
    center: LatLng(3.2248, 101.7294),
    pinALabel: 'KL East Mall Main Drop-off',
    pinBLabel: 'The Ridge & Park Residence',
    startNodeId: 'kl-n1',
    endNodeId: 'kl-n4',
    simulationEdge: <String>['kl-n2', 'kl-n3'],
    simulationLabel: 'Garden promenade closed for landscaping works',
    noiseSensors: <NoiseSensor>[
      NoiseSensor(
        id: 'kl-a1',
        position: LatLng(3.2241, 101.7285),
        db: 82,
        radiusMeters: 45,
        label: 'KL East Mall drop-off',
      ),
      NoiseSensor(
        id: 'kl-a2',
        position: LatLng(3.2248, 101.7295),
        db: 90,
        radiusMeters: 40,
        label: 'Roadside crossing at KL East',
      ),
      NoiseSensor(
        id: 'kl-a3',
        position: LatLng(3.2250, 101.7290),
        // Amber band: the promenade beside the mall forecourt is busy but
        // not loud, so this hub shows all three heatmap zones.
        db: 58,
        radiusMeters: 45,
        label: 'Garden promenade',
      ),
      NoiseSensor(
        id: 'kl-a4',
        position: LatLng(3.2256, 101.7305),
        db: 42,
        radiusMeters: 35,
        label: 'Residential lobby',
      ),
    ],
    nodes: <HubNode>[
      HubNode(
        id: 'kl-n1',
        label: 'KL East Mall Ground Entrance',
        position: LatLng(3.2241, 101.7285),
        kind: NodeKind.entrance,
        covered: true,
      ),
      HubNode(
        id: 'kl-n2',
        label: 'Step-Free Garden Promenade',
        position: LatLng(3.2250, 101.7290),
        kind: NodeKind.promenade,
      ),
      HubNode(
        id: 'kl-n3',
        label: 'Accessible Pedestrian Crossing',
        position: LatLng(3.2253, 101.7298),
        kind: NodeKind.crossing,
      ),
      HubNode(
        id: 'kl-n4',
        label: 'Residential Lobby Lift',
        position: LatLng(3.2256, 101.7305),
        kind: NodeKind.lift,
        covered: true,
      ),
      HubNode(
        id: 'kl-s1',
        label: 'Roadside Crossing at KL East',
        position: LatLng(3.2248, 101.7295),
        kind: NodeKind.crossing,
        stepFree: false,
      ),
    ],
    edges: <HubEdge>[
      HubEdge(
        from: 'kl-n1',
        to: 'kl-n2',
        covered: true,
        noiseLevel: NoiseLevel.moderate,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 2.6,
        label: 'Mall to garden promenade',
        geometry: <LatLng>[
          LatLng(3.2241, 101.7285),
          LatLng(3.2245, 101.7287),
          LatLng(3.2248, 101.7289),
          LatLng(3.2250, 101.7290),
        ],
      ),
      HubEdge(
        from: 'kl-n2',
        to: 'kl-n3',
        noiseLevel: NoiseLevel.quiet,
        lightLevel: LightLevel.moderate,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 2.8,
        label: 'Step-free garden promenade',
        geometry: <LatLng>[
          LatLng(3.2250, 101.7290),
          LatLng(3.2252, 101.7293),
          LatLng(3.2252, 101.7296),
          LatLng(3.2253, 101.7298),
        ],
      ),
      HubEdge(
        from: 'kl-n3',
        to: 'kl-n4',
        covered: true,
        noiseLevel: NoiseLevel.noisy,
        lightLevel: LightLevel.bright,
        hasTactilePaving: true,
        buggyAccessible: false,
        widthMeters: 1.9,
        label: 'Crossing to lobby lift',
        geometry: <LatLng>[
          LatLng(3.2253, 101.7298),
          LatLng(3.2254, 101.7300),
          LatLng(3.2255, 101.7303),
          LatLng(3.2256, 101.7305),
        ],
      ),
      HubEdge(
        from: 'kl-n1',
        to: 'kl-s1',
        noiseLevel: NoiseLevel.veryNoisy,
        lightLevel: LightLevel.veryBright,
        hasTactilePaving: false,
        buggyAccessible: false,
        widthMeters: 1.4,
        label: 'Roadside footpath',
        geometry: <LatLng>[
          LatLng(3.2241, 101.7285),
          LatLng(3.2244, 101.7288),
          LatLng(3.2246, 101.7292),
          LatLng(3.2248, 101.7295),
        ],
      ),
      HubEdge(
        from: 'kl-s1',
        to: 'kl-n4',
        hasStairs: true,
        noiseLevel: NoiseLevel.noisy,
        lightLevel: LightLevel.bright,
        hasTactilePaving: false,
        buggyAccessible: false,
        widthMeters: 1.2,
        label: 'Stairs to residence',
        geometry: <LatLng>[
          LatLng(3.2248, 101.7295),
          LatLng(3.2251, 101.7298),
          LatLng(3.2254, 101.7301),
          LatLng(3.2256, 101.7305),
        ],
      ),
      HubEdge(
        from: 'kl-n2',
        to: 'kl-n4',
        covered: true,
        noiseLevel: NoiseLevel.quiet,
        lightLevel: LightLevel.shaded,
        hasTactilePaving: true,
        buggyAccessible: true,
        widthMeters: 3.0,
        label: 'Lake side promenade detour',
        geometry: <LatLng>[
          LatLng(3.2250, 101.7290),
          LatLng(3.2262, 101.7294),
          LatLng(3.2260, 101.7303),
          LatLng(3.2256, 101.7305),
        ],
      ),
    ],
  );
}