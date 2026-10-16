import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';

/// Which tab is showing. Lets the header's points pill jump to Rewards.
class AppNav extends ChangeNotifier {
  static const routes = 0, report = 1, rewards = 2;

  int tab = routes;

  void go(int index) {
    if (tab == index) return;
    tab = index;
    notifyListeners();
  }
}

/// Points, rewards, vouchers and points history.
/// Kept in one place so the header, Report success and Rewards all agree.
class AppState extends ChangeNotifier {
  AppState(this.repo);

  final MapokuRepository repo;

  UserSummary? summary;
  List<Reward> rewards = const [];
  List<Voucher> vouchers = const [];
  List<PointsEntry> history = const [];

  int get points => summary?.points ?? 0;

  Future<void> load() async {
    final r = await Future.wait([
      repo.fetchSummary(),
      repo.fetchRewards(),
      repo.fetchVouchers(),
      repo.fetchPointsHistory(),
    ]);
    summary = r[0] as UserSummary;
    rewards = r[1] as List<Reward>;
    vouchers = r[2] as List<Voucher>;
    history = r[3] as List<PointsEntry>;
    notifyListeners();
  }

  Future<ReportReceipt> submitReport(ReportDraft draft) async {
    final receipt = await repo.submitReport(draft);
    final s = summary;
    if (s != null) {
      summary = s.copyWith(points: s.points + receipt.pointsNow, reports: s.reports + 1);
    }
    history = await repo.fetchPointsHistory();
    notifyListeners();
    return receipt;
  }

  Future<RedeemResult> redeem(Reward reward) async {
    final result = await repo.redeem(reward.id);
    summary = summary?.copyWith(points: result.pointsLeft);
    vouchers = [result.voucher, ...vouchers];
    history = await repo.fetchPointsHistory();
    notifyListeners();
    return result;
  }

  /// The cheapest reward the user can't afford yet, used for the progress hint.
  Reward? get nextGoal {
    final out = rewards.where((r) => r.cost > points).toList()..sort((a, b) => a.cost.compareTo(b.cost));
    return out.isEmpty ? null : out.first;
  }
}

/// The user's profile: accessibility needs, route preferences, emergency contacts.
class ProfileState extends ChangeNotifier {
  ProfileState(this.repo);

  final MapokuRepository repo;

  UserProfile? profile;

  Future<void> load() async {
    profile = await repo.fetchProfile();
    notifyListeners();
  }

  /// Applies the change immediately, then saves it. Reverts if saving fails.
  Future<void> update(UserProfile Function(UserProfile p) change) async {
    final before = profile;
    if (before == null) return;
    profile = change(before);
    notifyListeners();
    try {
      profile = await repo.saveProfile(profile!);
    } catch (_) {
      profile = before;
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}

enum ReportsFeed { community, mine }

/// Community feed and the user's own reports.
class ReportsController extends ChangeNotifier {
  ReportsController(this.repo);

  final MapokuRepository repo;

  ReportsFeed feed = ReportsFeed.community;
  List<CommunityReport> community = const [];
  List<CommunityReport> mine = const [];
  bool loading = false;
  String? error;

  List<CommunityReport> get visible => feed == ReportsFeed.community ? community : mine;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        repo.fetchCommunityReports(near: MockMapokuRepository.defaultPosition),
        repo.fetchMyReports(),
      ]);
      community = r[0];
      mine = r[1];
    } catch (_) {
      error = "Couldn't load reports. Pull down to try again.";
    }
    loading = false;
    notifyListeners();
  }

  void show(ReportsFeed f) {
    if (feed == f) return;
    feed = f;
    notifyListeners();
  }

  /// Updates the count straight away; the request runs in the background.
  Future<void> vote(CommunityReport report, {required bool stillThere}) async {
    if (report.myVote == stillThere) return;
    community = [for (final r in community) r.id == report.id ? r.withVote(stillThere) : r];
    notifyListeners();
    await repo.voteReport(report.id, stillThere: stillThere);
  }

  void addMine(CommunityReport report) {
    mine = [report, ...mine];
    feed = ReportsFeed.mine;
    notifyListeners();
  }
}
