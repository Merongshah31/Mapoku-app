import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';

enum RoutesPhase { idle, searching, results, navigating }

/// Drives the Routes tab: pick a township → search → compare routes → navigate.
class RoutesController extends ChangeNotifier {
  RoutesController(this.repo);

  final MapokuRepository repo;

  List<Township> townships = const [];
  Township? township;

  RoutesPhase phase = RoutesPhase.idle;
  RoutePlan? plan;
  RouteKind selected = RouteKind.stepFree;
  String? error;

  RouteOption? get selectedOption => plan?.option(selected);

  Future<void> load() async {
    townships = await repo.fetchTownships();
    township ??= townships.isEmpty ? null : townships.first;
    notifyListeners();
  }

  /// Switches township and clears any route from the previous one.
  void selectTownship(Township t) {
    if (township?.id == t.id) return;
    township = t;
    plan = null;
    error = null;
    selected = RouteKind.stepFree;
    phase = RoutesPhase.idle;
    notifyListeners();
  }

  Future<void> search({required String from, required String to, Set<MobilityNeed> needs = const {}}) async {
    final t = township;
    if (t == null) return;
    if (to.trim().isEmpty) {
      error = 'Enter where you want to go.';
      notifyListeners();
      return;
    }
    error = null;
    phase = RoutesPhase.searching;
    notifyListeners();
    try {
      plan = await repo.planRoute(townshipId: t.id, from: from, to: to, needs: needs);
      selected = RouteKind.stepFree;
      phase = RoutesPhase.results;
    } catch (_) {
      phase = RoutesPhase.idle;
      error = "Couldn't load routes. Check your connection and try again.";
    }
    notifyListeners();
  }

  void select(RouteKind kind) {
    if (selected == kind) return;
    selected = kind;
    notifyListeners();
  }

  void start() {
    phase = RoutesPhase.navigating;
    notifyListeners();
  }

  void endTrip() {
    phase = RoutesPhase.results;
    notifyListeners();
  }

  void clear() {
    phase = RoutesPhase.idle;
    plan = null;
    error = null;
    selected = RouteKind.stepFree;
    notifyListeners();
  }
}
