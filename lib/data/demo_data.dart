import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import '../models/report.dart';
import '../models/reward.dart';

/// Hardcoded demo data for the community feed, reports and rewards wallet.
class DemoData {
  const DemoData._();

  // ---------------------------------------------------------------------------
  // Reported obstacles around the Klang Valley demo area
  // ---------------------------------------------------------------------------

  static final List<Obstacle> routeObstacles = <Obstacle>[
    const Obstacle(
      id: 'obs-1',
      type: ObstacleType.noRamp,
      position: LatLng(2.9258, 101.6432),
      location: 'Maybank Seksyen 7',
      description: 'No ramp — stairs only at entrance.',
      ago: '3h ago',
      confirms: 9,
    ),
    const Obstacle(
      id: 'obs-2',
      type: ObstacleType.liftBroken,
      position: LatLng(2.9247, 101.6448),
      location: 'Maybank Seksyen 7',
      description: 'Lift out of service.',
      ago: '1d ago',
      confirms: 5,
    ),
    const Obstacle(
      id: 'obs-3',
      type: ObstacleType.pathBlocked,
      position: LatLng(2.9240, 101.6458),
      location: 'Maybank Seksyen 7',
      description: 'Accessible parking blocked by works.',
      ago: '6h ago',
      confirms: 3,
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
      emoji: '🚗',
      tagline: 'Off your next accessible ride',
      colorValue: 0xFF1EAB57,
    ),
    Reward(
      id: 'grab10',
      brand: 'Grab',
      label: 'RM10 ride credit',
      cost: 500,
      emoji: '🚙',
      tagline: 'Best value for longer trips',
      colorValue: 0xFF14803F,
    ),
    Reward(
      id: 'tng3',
      brand: "Touch 'n Go",
      label: 'RM3 eWallet reload',
      cost: 300,
      emoji: '💳',
      tagline: 'Reload your TNG eWallet',
      colorValue: 0xFF0F6FB8,
    ),
    Reward(
      id: 'coffee',
      brand: 'Community Cafe',
      label: 'Free coffee',
      cost: 250,
      emoji: '☕️',
      tagline: 'On us, at partner cafes',
      colorValue: 0xFFC27A45,
    ),
    Reward(
      id: 'partner',
      brand: 'Access Partner',
      label: 'RM15 voucher',
      cost: 700,
      emoji: '🎁',
      tagline: 'Accessibility equipment partner',
      colorValue: 0xFF346F4B,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Community obstacle feed
  // ---------------------------------------------------------------------------

  static final List<Obstacle> communityObstacles = <Obstacle>[
    ...routeObstacles,
    const Obstacle(
      id: 'obs-4',
      type: ObstacleType.unevenSurface,
      position: LatLng(3.118, 101.696),
      location: 'Mid Valley, Kuala Lumpur',
      description: 'Uneven pavement near the accessible drop-off.',
      ago: '2h ago',
      confirms: 7,
    ),
    const Obstacle(
      id: 'obs-5',
      type: ObstacleType.liftBroken,
      position: LatLng(3.134, 101.686),
      location: 'KL Sentral, Kuala Lumpur',
      description: 'Lift to the concourse is out of service.',
      ago: '5h ago',
      confirms: 12,
    ),
    const Obstacle(
      id: 'obs-6',
      type: ObstacleType.pathBlocked,
      position: LatLng(3.157, 101.712),
      location: 'Bukit Bintang, Kuala Lumpur',
      description: 'Construction barrier blocks the tactile path.',
      ago: '1d ago',
      confirms: 4,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Seeded "My Reports" (includes verified / flagged examples for the demo)
  // ---------------------------------------------------------------------------

  static List<Report> myReports() => <Report>[
        Report(
          id: 'demo-verified',
          type: ObstacleType.pathBlocked.label,
          icon: ObstacleType.pathBlocked.icon,
          location: 'Mid Valley, Kuala Lumpur',
          description: 'Temporary construction barrier reported near the accessible entrance.',
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          status: ReportStatus.verified,
          confirmations: 9,
          clearances: 1,
          isMine: true,
        ),
        Report(
          id: 'demo-flagged',
          type: ObstacleType.liftBroken.label,
          icon: ObstacleType.liftBroken.icon,
          location: 'KL Sentral, Kuala Lumpur',
          description: 'Lift access issue reported with an uploaded photo.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          status: ReportStatus.flagged,
          flagReason: 'Photo is not related to the reported obstacle.',
          isMine: true,
        ),
      ];
}