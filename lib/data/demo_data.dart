import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../features/sime_darby/data/sime_darby_demo_data.dart';
import '../features/sime_darby/models/sime_darby_hub.dart';
import '../models/obstacle.dart';
import '../models/report.dart';
import '../models/reward.dart';

/// Hardcoded demo data for the community feed, reports and rewards wallet.
///
/// Every report sits at one of the three Sime Darby Property sites, pinned
/// on a named wayfinding point so it lines up with the walkways.
class DemoData {
  const DemoData._();

  static const SimeDarbyHub _sjcc = SimeDarbyDemoData.sjcc;
  static const SimeDarbyHub _elmina = SimeDarbyDemoData.elmina;
  static const SimeDarbyHub _klEast = SimeDarbyDemoData.klEast;

  static LatLng _at(SimeDarbyHub hub, String nodeId) =>
      hub.nodeById(nodeId).position;

  static String _where(SimeDarbyHub hub, String nodeId) =>
      '${hub.nodeById(nodeId).label} · ${hub.name}';

  // ---------------------------------------------------------------------------
  // Community obstacle feed
  // ---------------------------------------------------------------------------

  static final List<Obstacle> communityObstacles = <Obstacle>[
    Obstacle(
      id: 'obs-1',
      type: ObstacleType.noRamp,
      position: _at(_sjcc, 'sj-s1'),
      location: _where(_sjcc, 'sj-s1'),
      description:
          'Stairs only on the shortcut\nNo ramp or lift on the steps towards the retail hub.',
      ago: '3h ago',
      confirms: 9,
    ),
    Obstacle(
      id: 'obs-2',
      type: ObstacleType.vehicleBlocking,
      position: _at(_sjcc, 'sj-s1'),
      location: _where(_sjcc, 'sj-s1'),
      description: 'Delivery van parked across the station service road.',
      ago: '1d ago',
      confirms: 5,
    ),
    Obstacle(
      id: 'obs-3',
      type: ObstacleType.unevenSurface,
      position: _at(_elmina, 'el-s1'),
      location: _where(_elmina, 'el-s1'),
      description: 'Uneven pavement at the roadside crossing.',
      ago: '2h ago',
      confirms: 7,
    ),
    Obstacle(
      id: 'obs-4',
      type: ObstacleType.highKerb,
      position: _at(_elmina, 'el-s1'),
      location: _where(_elmina, 'el-s1'),
      description: 'No kerb ramp on the far side of the crossing.',
      ago: '5h ago',
      confirms: 12,
    ),
    Obstacle(
      id: 'obs-5',
      type: ObstacleType.pathBlocked,
      position: _at(_klEast, 'kl-s1'),
      location: _where(_klEast, 'kl-s1'),
      description: 'Construction barrier across the roadside footpath.',
      ago: '1d ago',
      confirms: 4,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Rewards catalogue (hardcoded so redeem always works on stage)
  // ---------------------------------------------------------------------------

  static const List<Reward> rewards = <Reward>[
    Reward(
      id: 'grab5',
      brand: 'Grab',
      label: 'RM5 ride credit',
      cost: 350,
      icon: Icons.directions_car,
      tagline: 'Off your next accessible ride',
      colorValue: 0xFF1EAB57,
    ),
    Reward(
      id: 'grab10',
      brand: 'Grab',
      label: 'RM10 ride credit',
      cost: 500,
      icon: Icons.local_taxi,
      tagline: 'Best value for longer trips',
      colorValue: 0xFF14803F,
    ),
    Reward(
      id: 'tng3',
      brand: "Touch 'n Go",
      label: 'RM3 eWallet reload',
      cost: 300,
      icon: CupertinoIcons.creditcard,
      tagline: 'Reload your TNG eWallet',
      colorValue: 0xFF0F6FB8,
    ),
    Reward(
      id: 'coffee',
      brand: 'Community Cafe',
      label: 'Free coffee',
      cost: 250,
      icon: Icons.coffee,
      tagline: 'On us, at partner cafes',
      colorValue: 0xFFC27A45,
    ),
    Reward(
      id: 'partner',
      brand: 'Access Partner',
      label: 'RM15 voucher',
      cost: 700,
      icon: CupertinoIcons.gift,
      tagline: 'Accessibility equipment partner',
      colorValue: 0xFF346F4B,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Seeded "My Reports" (includes verified / flagged examples for the demo)
  // ---------------------------------------------------------------------------

  static List<Report> myReports() => <Report>[
    Report(
      id: 'demo-verified',
      type: ObstacleType.unevenSurface.label,
      location: _where(_elmina, 'el-n2'),
      description:
          'Loose paving slab\nA slab has lifted on the tactile walkway.',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      status: ReportStatus.verified,
      confirmations: 9,
      clearances: 1,
      isMine: true,
      position: _at(_elmina, 'el-n2'),
    ),
    Report(
      id: 'demo-flagged',
      type: ObstacleType.liftBroken.label,
      location: _where(_klEast, 'kl-n4'),
      description: 'Lift access issue reported with an uploaded photo.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: ReportStatus.flagged,
      flagReason: 'Photo is not related to the reported obstacle.',
      isMine: true,
      position: _at(_klEast, 'kl-n4'),
    ),
  ];
}
