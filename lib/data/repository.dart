import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'sime_darby_demo.dart';

/// The single seam between the UI and the backend.
///
/// Screens only talk to this interface. Today the app runs on
/// [MockMapokuRepository]; when the endpoints in API_CONTRACT.md are live,
/// write an `ApiMapokuRepository implements MapokuRepository` and swap it in
/// `main.dart`. No widget code needs to change.
abstract class MapokuRepository {
  // Townships & routes
  Future<List<Township>> fetchTownships();
  Future<RoutePlan> planRoute({
    required String townshipId,
    required String from,
    required String to,
    required Set<MobilityNeed> needs,
  });
  Future<void> confirmObstacle(String obstacleId, {required bool stillThere});

  // Reports
  Future<List<CommunityReport>> fetchCommunityReports({required LatLng near});
  Future<List<CommunityReport>> fetchMyReports();
  Future<void> voteReport(String reportId, {required bool stillThere});
  Future<ReportReceipt> submitReport(ReportDraft draft);

  // Profile
  Future<UserProfile> fetchProfile();
  Future<UserProfile> saveProfile(UserProfile profile);

  // Points & rewards
  Future<UserSummary> fetchSummary();
  Future<List<Reward>> fetchRewards();
  Future<List<Voucher>> fetchVouchers();
  Future<List<PointsEntry>> fetchPointsHistory();
  Future<RedeemResult> redeem(String rewardId);
}

/// Demo data set in three Sime Darby Property hubs (SJCC / SJ7, City of
/// Elmina, KL East). Routes come from [SimeDarbyDemo].
class MockMapokuRepository implements MapokuRepository {
  MockMapokuRepository({this.latency = const Duration(milliseconds: 700)});

  /// Fake network delay, so loading states get exercised before the API exists.
  final Duration latency;

  final _rng = Random();
  int _points = 620;
  int _reportsSent = 18;
  final List<Voucher> _vouchers = [];
  late final List<PointsEntry> _history = _seedHistory();
  late final List<CommunityReport> _mine = _seedMine();

  UserProfile _profile = const UserProfile(
    name: 'Auni',
    email: 'auni@example.com',
    needs: {MobilityNeed.wheelchair},
    prefs: RoutePrefs(),
    needsNote: 'Manual wheelchair, about 65 cm wide',
    contacts: [
      EmergencyContact(id: 'ec_1', name: 'Aminah', relationship: 'Mother', phone: '+60 12-345 6789'),
    ],
  );

  /// Fallback when GPS is off or permission is denied: SJ7 station, Subang Jaya.
  static final defaultPosition = LatLng(3.0845, 101.5861);

  Future<void> _wait([double f = 1]) => Future.delayed(latency * f);

  // ------------------------------------------------------------ routes

  @override
  Future<List<Township>> fetchTownships() async {
    await _wait(0.3);
    return SimeDarbyDemo.townships;
  }

  @override
  Future<RoutePlan> planRoute({
    required String townshipId,
    required String from,
    required String to,
    required Set<MobilityNeed> needs,
  }) async {
    await _wait();
    return SimeDarbyDemo.plan(townshipId);
  }

  @override
  Future<void> confirmObstacle(String obstacleId, {required bool stillThere}) => _wait(0.5);

  // ------------------------------------------------------------ reports

  @override
  Future<List<CommunityReport>> fetchCommunityReports({required LatLng near}) async {
    await _wait();
    final now = DateTime.now();
    return [
      CommunityReport(
        id: 'cr_1',
        kind: ObstacleKind.liftBroken,
        summary: 'Lift at SJ7 LRT Entrance B out of service',
        details: 'Staff said it should be fixed by Friday. The lift at Entrance A is working.',
        placeName: 'Subang Jaya LRT/KTM Station (SJ7)',
        position: LatLng(3.0846, 101.5862),
        seenAt: now.subtract(const Duration(hours: 2)),
        stillThere: 14,
        gone: 1,
        status: ReportStatus.verified,
      ),
      CommunityReport(
        id: 'cr_2',
        kind: ObstacleKind.parkingMisused,
        summary: 'OKU drop-off zone blocked by e-hailing cars',
        details: 'Three cars waiting in the drop-off bays. Had to get out on the main road.',
        placeName: 'SJCC, OKU Drop-off Zone',
        position: LatLng(3.0843, 101.5889),
        seenAt: now.subtract(const Duration(hours: 5)),
        stillThere: 6,
        gone: 0,
        status: ReportStatus.verified,
      ),
      CommunityReport(
        id: 'cr_3',
        kind: ObstacleKind.noTactilePaving,
        summary: 'Tactile tiles loose along the park walkway',
        details: 'About five tiles are lifted near the playground, easy to trip on with a cane.',
        placeName: 'Elmina Central Park, Tactile Walkway',
        position: LatLng(3.1846, 101.5131),
        seenAt: now.subtract(const Duration(hours: 9)),
        stillThere: 3,
        gone: 2,
      ),
      CommunityReport(
        id: 'cr_4',
        kind: ObstacleKind.toiletUnavailable,
        summary: 'Accessible toilet on level 1 closed',
        details: 'Sign says under maintenance. The one on the ground floor near the food court is open.',
        placeName: 'Elmina Lakeside Mall',
        position: LatLng(3.1851, 101.5152),
        seenAt: now.subtract(const Duration(days: 1, hours: 3)),
        stillThere: 8,
        gone: 0,
        status: ReportStatus.verified,
      ),
      CommunityReport(
        id: 'cr_5',
        kind: ObstacleKind.flooding,
        summary: 'Garden promenade flooded after rain',
        placeName: 'KL East, Garden Promenade',
        position: LatLng(3.2251, 101.7292),
        seenAt: now.subtract(const Duration(days: 2)),
        stillThere: 1,
        gone: 5,
      ),
      CommunityReport(
        id: 'cr_6',
        kind: ObstacleKind.steepSlope,
        summary: 'Ramp at the mall drop-off is too steep',
        details: 'Needed help pushing up. No handrail on the left side.',
        placeName: 'KL East Mall Main Drop-off',
        position: LatLng(3.2241, 101.7285),
        seenAt: now.subtract(const Duration(days: 3)),
        stillThere: 4,
        gone: 0,
      ),
    ];
  }

  List<CommunityReport> _seedMine() {
    final now = DateTime.now();
    return [
      CommunityReport(
        id: 'my_1',
        kind: ObstacleKind.pathBlocked,
        summary: 'Barrier covering the ramp to the mall',
        details: 'Temporary construction barrier across the north wheelchair ramp.',
        placeName: 'Elmina Lakeside Mall, North Ramp',
        position: LatLng(3.1855, 101.5140),
        seenAt: now.subtract(const Duration(days: 1)),
        stillThere: 6,
        status: ReportStatus.verified,
      ),
      CommunityReport(
        id: 'my_2',
        kind: ObstacleKind.liftBroken,
        summary: 'Lift not working',
        details: 'Lift access issue, reported with a photo.',
        placeName: 'Subang Jaya LRT/KTM Station (SJ7)',
        position: LatLng(3.0845, 101.5861),
        seenAt: now.subtract(const Duration(days: 3)),
        status: ReportStatus.flagged,
        flagReason: "The photo doesn't show the lift. Send a new report with a clearer photo.",
      ),
    ];
  }

  @override
  Future<List<CommunityReport>> fetchMyReports() async {
    await _wait(0.5);
    return List.of(_mine);
  }

  @override
  Future<void> voteReport(String reportId, {required bool stillThere}) => _wait(0.4);

  @override
  Future<ReportReceipt> submitReport(ReportDraft d) async {
    await _wait();
    final report = CommunityReport(
      id: 'my_${_rng.nextInt(99999)}',
      kind: d.kind,
      summary: d.summary,
      details: d.details,
      placeName: d.placeName,
      position: d.position,
      seenAt: d.seenAt,
      localPhotoPath: d.photoPath,
    );
    _mine.insert(0, report);
    _points += 10;
    _reportsSent += 1;
    _history.insert(
      0,
      PointsEntry(id: 'pe_${_rng.nextInt(99999)}', title: 'Report sent', detail: d.summary, amount: 10, at: DateTime.now()),
    );
    return ReportReceipt(report: report, pointsNow: 10, pointsOnConfirm: 40);
  }

  // ------------------------------------------------------------ profile

  @override
  Future<UserProfile> fetchProfile() async {
    await _wait(0.5);
    return _profile;
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    await _wait(0.4);
    _profile = profile;
    return _profile;
  }

  // ------------------------------------------------------------ rewards

  @override
  Future<UserSummary> fetchSummary() async {
    await _wait(0.5);
    return UserSummary(points: _points, reports: _reportsSent, confirmations: 46);
  }

  static const _rewards = [
    Reward(
      id: 'rw_grab_assist',
      partner: RewardPartner.grab,
      category: RewardCategory.rides,
      title: 'RM8 off GrabAssist',
      description: 'Rides with drivers trained to help wheelchair users and seniors.',
      cost: 450,
    ),
    Reward(
      id: 'rw_grab_5',
      partner: RewardPartner.grab,
      category: RewardCategory.rides,
      title: 'RM5 ride credit',
      description: 'Any GrabCar ride in the Klang Valley.',
      cost: 350,
    ),
    Reward(
      id: 'rw_grab_10',
      partner: RewardPartner.grab,
      category: RewardCategory.rides,
      title: 'RM10 ride credit',
      description: 'Any GrabCar ride in the Klang Valley.',
      cost: 650,
    ),
    Reward(
      id: 'rw_rapid_trip',
      partner: RewardPartner.rapidKL,
      category: RewardCategory.transit,
      title: 'Free LRT or MRT trip',
      description: 'One trip, any distance, on Rapid KL rail lines.',
      cost: 250,
    ),
    Reward(
      id: 'rw_rapid_day',
      partner: RewardPartner.rapidKL,
      category: RewardCategory.transit,
      title: '1-day unlimited pass',
      description: 'Unlimited LRT, MRT, monorail and Rapid KL buses for a day.',
      cost: 700,
    ),
    Reward(
      id: 'rw_tng_3',
      partner: RewardPartner.touchNGo,
      category: RewardCategory.ewallet,
      title: 'RM3 eWallet reload',
      description: "Added to your Touch 'n Go eWallet.",
      cost: 300,
    ),
  ];

  @override
  Future<List<Reward>> fetchRewards() async {
    await _wait(0.5);
    return _rewards;
  }

  @override
  Future<List<Voucher>> fetchVouchers() async {
    await _wait(0.5);
    return List.of(_vouchers);
  }

  List<PointsEntry> _seedHistory() {
    final now = DateTime.now();
    return [
      PointsEntry(id: 'pe_1', title: 'Report confirmed', detail: 'Barrier covering the ramp, Elmina Lakeside Mall', amount: 40, at: now.subtract(const Duration(hours: 20))),
      PointsEntry(id: 'pe_2', title: 'Report sent', detail: 'Barrier covering the ramp, Elmina Lakeside Mall', amount: 10, at: now.subtract(const Duration(days: 1))),
      PointsEntry(id: 'pe_3', title: 'You confirmed a report', detail: 'Lift at SJ7 LRT Entrance B', amount: 5, at: now.subtract(const Duration(days: 2))),
      PointsEntry(id: 'pe_4', title: 'Redeemed', detail: 'Grab RM5 ride credit', amount: -350, at: now.subtract(const Duration(days: 6))),
      PointsEntry(id: 'pe_5', title: 'Report confirmed', detail: 'OKU drop-off zone blocked, SJCC', amount: 40, at: now.subtract(const Duration(days: 8))),
    ];
  }

  @override
  Future<List<PointsEntry>> fetchPointsHistory() async {
    await _wait(0.5);
    return List.of(_history);
  }

  @override
  Future<RedeemResult> redeem(String rewardId) async {
    await _wait();
    final r = _rewards.firstWhere((x) => x.id == rewardId);
    if (_points < r.cost) throw StateError('Not enough points');
    _points -= r.cost;
    // No 0/O or 1/I so the code can't be misread.
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final body = List.generate(6, (_) => alphabet[_rng.nextInt(alphabet.length)]).join();
    final prefix = switch (r.partner) {
      RewardPartner.grab => 'GRB',
      RewardPartner.touchNGo => 'TNG',
      RewardPartner.rapidKL => 'RKL',
    };
    final now = DateTime.now();
    final v = Voucher(code: '$prefix-$body', reward: r, redeemedAt: now, expiresAt: now.add(const Duration(days: 30)));
    _vouchers.insert(0, v);
    _history.insert(
      0,
      PointsEntry(id: 'pe_${_rng.nextInt(99999)}', title: 'Redeemed', detail: '${r.partnerName} ${r.title}', amount: -r.cost, at: now),
    );
    return RedeemResult(voucher: v, pointsLeft: _points);
  }
}
