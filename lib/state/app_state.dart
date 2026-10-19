import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_config.dart';
import '../data/demo_data.dart';
import '../features/sime_darby/data/sime_darby_demo_data.dart';
import '../features/sime_darby/models/sime_darby_hub.dart';
import '../models/obstacle.dart';
import '../models/profile.dart';
import '../models/report.dart';
import '../models/reward.dart';
import '../services/mapoku_api_service.dart';
import '../services/rewards_repository.dart';

enum ServiceHealth { checking, online, offline }

/// Single source of truth for the running app.
///
/// Blends guaranteed demo data with real API calls: the obstacle feed and
/// service health come from the backend when reachable and gracefully fall
/// back to hardcoded data otherwise.
class AppState extends ChangeNotifier {
  AppState({MapokuApiService? api, RewardsRepository? rewards})
    : _api = api ?? MapokuApiService(),
      _rewards = rewards ?? RewardsRepository();

  final MapokuApiService _api;
  final RewardsRepository _rewards;

  // Wallet
  int _points = AppConfig.startingPoints;
  List<Redemption> _redemptions = const [];
  int get points => _points;
  List<Redemption> get redemptions => _redemptions;

  // Profile (needs, route preferences, emergency contacts; stored on device)
  UserProfile _profile = const UserProfile();
  UserProfile get profile => _profile;

  /// Name shown for the member: their chosen name, else the signed-in one.
  String get memberName =>
      _profile.name.isNotEmpty ? _profile.name : displayName;

  Future<void> updateProfile(UserProfile Function(UserProfile) change) async {
    _profile = change(_profile);
    notifyListeners();
    await _rewards.saveProfile(_profile);
  }

  // Auth (demo only: identifies the community member)
  String? _userName;
  String? _userEmail;
  bool get isLoggedIn => _userName != null || _userEmail != null;
  String get displayName => _userName ?? _userEmail ?? 'Guest';

  // Service health
  ServiceHealth _health = ServiceHealth.checking;
  ServiceHealth get health => _health;

  // Map & reports
  /// Reports already on file for each Sime Darby hub, e.g. fenced-off works.
  static final List<Obstacle> _hubReports = <Obstacle>[
    for (final hub in SimeDarbyDemoData.hubs)
      if (hub.simulatedEdge != null)
        Obstacle(
          id: 'sdp-${hub.id}',
          type: ObstacleType.pathBlocked,
          position: polylineMidpoint(hub.simulatedEdge!.geometry),
          location: hub.simulationLabel,
          description:
              'Walkway fenced off for works\nTemporary barrier across the walkway. Use the detour.',
          ago: '2 h ago',
          confirms: 6,
        ),
  ];

  List<Obstacle> _communityObstacles = [
    ..._hubReports,
    ...DemoData.communityObstacles,
  ];
  List<Obstacle> get communityObstacles => _communityObstacles;

  final List<Report> _myReports = [...DemoData.myReports()];
  List<Report> get myReports => _myReports;

  bool _busy = false;
  bool get busy => _busy;

  Future<void> init() async {
    _points = await _rewards.loadPoints();
    _redemptions = await _rewards.loadHistory();
    _profile = await _rewards.loadProfile();
    final token = await _rewards.loadToken();
    if (token != null) _api.setToken(token);
    notifyListeners();

    _checkHealth();
    _loadCommunityObstacles();
  }

  Future<void> _checkHealth() async {
    final online = await _api.healthCheck();
    _health = online ? ServiceHealth.online : ServiceHealth.offline;
    notifyListeners();
  }

  Future<void> _loadCommunityObstacles() async {
    try {
      final remote = await _api.getObstaclesInView(
        minLat: 2.8,
        minLng: 101.4,
        maxLat: 3.4,
        maxLng: 101.9,
      );
      if (remote.isNotEmpty) {
        final remoteIds = {for (final o in remote) o.id};
        _communityObstacles = [
          ...remote,
          ..._communityObstacles.where(
            (o) => o.id.startsWith('sdp-') && !remoteIds.contains(o.id),
          ),
        ];
        notifyListeners();
      }
    } catch (_) {
      // Keep the hardcoded demo feed.
    }
  }

  // ---------------------------------------------------------------------------
  // Obstacle confirmations
  // ---------------------------------------------------------------------------

  void confirmObstacle(String id) {
    _communityObstacles = _communityObstacles
        .map((o) => o.id == id ? o.copyWith(confirms: o.confirms + 1) : o)
        .toList();
    _addPoints(2);
    _api.upvoteObstacle(id).ignore();
    notifyListeners();
  }

  void clearObstacle(String id) {
    _communityObstacles = _communityObstacles
        .map((o) => o.id == id ? o.copyWith(clearances: o.clearances + 1) : o)
        .toList();
    _api.downvoteObstacle(id).ignore();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  /// Adds a community report locally, awards points and syncs to the backend.
  void submitReport({
    required ObstacleType type,
    required LatLng position,
    required String location,
    required String description,
    String? imagePath,
  }) {
    final id = 'local-${DateTime.now().millisecondsSinceEpoch}';

    _myReports.insert(
      0,
      Report(
        id: id,
        type: type.label,
        icon: type.icon,
        location: location,
        description: description.isEmpty
            ? 'Accessibility obstacle reported from mapOKU.'
            : description,
        imagePath: imagePath,
        createdAt: DateTime.now(),
        status: ReportStatus.pending,
        isMine: true,
        position: position,
      ),
    );

    _communityObstacles = [
      Obstacle(
        id: id,
        type: type,
        position: position,
        location: location,
        description: description,
        ago: 'just now',
        confirms: 0,
      ),
      ..._communityObstacles,
    ];

    _addPoints(AppConfig.pointsPerReport);
    _api
        .submitObstacle(
          type: type,
          position: position,
          description: description,
          imagePath: imagePath,
        )
        .ignore();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Wallet
  // ---------------------------------------------------------------------------

  /// Redeems a reward, returning the generated code or `null` if unaffordable.
  Redemption? redeem(Reward reward) {
    if (reward.cost > _points) return null;

    final redemption = Redemption(
      rewardId: reward.id,
      brand: reward.brand,
      label: reward.label,
      code: _rewards.generateCode(reward.brand),
      cost: reward.cost,
      redeemedAt: DateTime.now(),
    );

    _points -= reward.cost;
    _redemptions = [redemption, ..._redemptions];
    _rewards.savePoints(_points);
    _rewards.saveHistory(_redemptions);
    notifyListeners();
    return redemption;
  }

  void _addPoints(int amount) {
    _points += amount;
    _rewards.savePoints(_points);
  }

  // ---------------------------------------------------------------------------
  // Auth (demo)
  // ---------------------------------------------------------------------------

  Future<void> signIn({required String email, required String password}) async {
    _busy = true;
    notifyListeners();
    try {
      final response = await _api.login(email: email, password: password);
      final token = response['token']?.toString();
      final user = response['user'] ?? response['data'] ?? response;
      if (user is Map) {
        _userEmail = user['email']?.toString() ?? email;
        _userName = (user['username'] ?? user['name'])?.toString();
      } else {
        _userEmail = email;
      }
      if (token != null) {
        _api.setToken(token);
        await _rewards.saveToken(token);
      }
    } catch (_) {
      // Offline-friendly fallback: still sign in locally for the demo.
      _userEmail = email;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void signOut() {
    _userName = null;
    _userEmail = null;
    _api.setToken(null);
    _rewards.saveToken(null);
    notifyListeners();
  }
}
