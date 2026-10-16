import 'package:latlong2/latlong.dart';

/// Data models for mapOKU.
///
/// Every model has a `fromJson` factory whose keys match API_CONTRACT.md, so
/// the backend can return these shapes directly and nothing in the UI changes.

LatLng _latLng(Map<String, dynamic> j) =>
    LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());

Map<String, dynamic> latLngJson(LatLng p) => {'lat': p.latitude, 'lng': p.longitude};

List<LatLng> _path(List<dynamic> raw) =>
    raw.map((p) => _latLng(p as Map<String, dynamic>)).toList();

class Place {
  final String name;
  final String area;
  final LatLng position;

  const Place({required this.name, required this.area, required this.position});

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        area: (j['area'] as String?) ?? '',
        position: _latLng(j['position'] as Map<String, dynamic>),
      );
}

// ---------------------------------------------------------------- obstacles

/// The kinds of barrier a user can report. `apiValue` is what the backend stores.
enum ObstacleKind {
  noRamp('no_ramp', 'No ramp, stairs only'),
  liftBroken('lift_broken', 'Lift not working'),
  escalatorBroken('escalator_broken', 'Escalator not working'),
  pathBlocked('path_blocked', 'Path blocked'),
  unevenSurface('uneven_surface', 'Uneven or broken surface'),
  narrowPath('narrow_path', 'Path too narrow'),
  steepSlope('steep_slope', 'Ramp or slope too steep'),
  noDroppedKerb('no_dropped_kerb', 'No dropped kerb'),
  noTactilePaving('no_tactile_paving', 'Tactile paving missing'),
  parkingMisused('parking_misused', 'OKU parking taken'),
  toiletUnavailable('toilet_unavailable', 'Accessible toilet closed'),
  heavyDoor('heavy_door', 'Door too heavy or narrow'),
  flooding('flooding', 'Flooding or deep puddles'),
  poorLighting('poor_lighting', 'Too dark to see'),
  other('other', 'Something else');

  final String apiValue;
  final String label;
  const ObstacleKind(this.apiValue, this.label);

  static ObstacleKind fromApi(String v) =>
      values.firstWhere((k) => k.apiValue == v, orElse: () => other);
}

/// An obstacle as it appears on a planned route.
class Obstacle {
  final String id;
  final ObstacleKind kind;
  final String title;
  final LatLng position;
  final DateTime reportedAt;
  final int confirmations;

  const Obstacle({
    required this.id,
    required this.kind,
    required this.title,
    required this.position,
    required this.reportedAt,
    required this.confirmations,
  });

  factory Obstacle.fromJson(Map<String, dynamic> j) => Obstacle(
        id: j['id'] as String,
        kind: ObstacleKind.fromApi(j['kind'] as String),
        title: j['title'] as String,
        position: _latLng(j['position'] as Map<String, dynamic>),
        reportedAt: DateTime.parse(j['reported_at'] as String),
        confirmations: j['confirmations'] as int,
      );
}

enum ReportStatus { pending, verified, flagged }

/// A report in the Community feed or in My reports.
class CommunityReport {
  final String id;
  final ObstacleKind kind;
  final String summary;
  final String? details;
  final String placeName;
  final LatLng position;
  final DateTime seenAt;
  final String? photoUrl;

  /// Local photo for reports this device just sent (before the URL exists).
  final String? localPhotoPath;
  final int stillThere;
  final int gone;

  /// This user's vote: true = still there, false = gone, null = not voted.
  final bool? myVote;
  final ReportStatus status;
  final String? flagReason;

  const CommunityReport({
    required this.id,
    required this.kind,
    required this.summary,
    required this.placeName,
    required this.position,
    required this.seenAt,
    this.details,
    this.photoUrl,
    this.localPhotoPath,
    this.stillThere = 0,
    this.gone = 0,
    this.myVote,
    this.status = ReportStatus.pending,
    this.flagReason,
  });

  CommunityReport withVote(bool stillThereVote) {
    // Changing a vote moves it from one count to the other.
    var s = stillThere, g = gone;
    if (myVote == true) s--;
    if (myVote == false) g--;
    if (stillThereVote) {
      s++;
    } else {
      g++;
    }
    return CommunityReport(
      id: id,
      kind: kind,
      summary: summary,
      details: details,
      placeName: placeName,
      position: position,
      seenAt: seenAt,
      photoUrl: photoUrl,
      localPhotoPath: localPhotoPath,
      stillThere: s,
      gone: g,
      myVote: stillThereVote,
      status: status,
      flagReason: flagReason,
    );
  }

  factory CommunityReport.fromJson(Map<String, dynamic> j) => CommunityReport(
        id: j['id'] as String,
        kind: ObstacleKind.fromApi(j['kind'] as String),
        summary: j['summary'] as String,
        details: j['details'] as String?,
        placeName: j['place_name'] as String,
        position: _latLng(j['position'] as Map<String, dynamic>),
        seenAt: DateTime.parse(j['seen_at'] as String),
        photoUrl: j['photo_url'] as String?,
        stillThere: (j['still_there'] as int?) ?? 0,
        gone: (j['gone'] as int?) ?? 0,
        myVote: j['my_vote'] as bool?,
        status: ReportStatus.values.byName((j['status'] as String?) ?? 'pending'),
        flagReason: j['flag_reason'] as String?,
      );
}

/// What the user fills in on the New report screen.
class ReportDraft {
  final ObstacleKind kind;
  final LatLng position;
  final String placeName;
  final DateTime seenAt;
  final String summary;
  final String? details;

  /// Local file path of the photo, uploaded as multipart by the API layer.
  final String? photoPath;

  const ReportDraft({
    required this.kind,
    required this.position,
    required this.placeName,
    required this.seenAt,
    required this.summary,
    this.details,
    this.photoPath,
  });
}

class ReportReceipt {
  final CommunityReport report;
  final int pointsNow;
  final int pointsOnConfirm;

  const ReportReceipt({required this.report, required this.pointsNow, required this.pointsOnConfirm});

  factory ReportReceipt.fromJson(Map<String, dynamic> j) => ReportReceipt(
        report: CommunityReport.fromJson(j['report'] as Map<String, dynamic>),
        pointsNow: j['points_now'] as int,
        pointsOnConfirm: j['points_on_confirm'] as int,
      );
}

// ---------------------------------------------------------------- routes

enum Turn { straight, left, right, arrive }

class RouteStep {
  final Turn turn;
  final String instruction;
  final String? caution;

  const RouteStep({required this.turn, required this.instruction, this.caution});

  factory RouteStep.fromJson(Map<String, dynamic> j) => RouteStep(
        turn: Turn.values.byName(j['turn'] as String),
        instruction: j['instruction'] as String,
        caution: j['caution'] as String?,
      );
}

enum RouteKind { stepFree, standard }

class RouteOption {
  final RouteKind kind;
  final Place destination;
  final int minutes;
  final int meters;
  final List<LatLng> path;
  final List<String> obstacleIds;
  final List<RouteStep> steps;

  /// What makes this route easier, e.g. "Covered link bridge". Shown under
  /// "Why this route" for the OKU-safe option.
  final List<String> highlights;

  const RouteOption({
    required this.kind,
    required this.destination,
    required this.minutes,
    required this.meters,
    required this.path,
    required this.obstacleIds,
    required this.steps,
    this.highlights = const [],
  });

  factory RouteOption.fromJson(Map<String, dynamic> j) => RouteOption(
        kind: j['kind'] == 'step_free' ? RouteKind.stepFree : RouteKind.standard,
        destination: Place.fromJson(j['destination'] as Map<String, dynamic>),
        minutes: j['minutes'] as int,
        meters: j['meters'] as int,
        path: _path(j['path'] as List<dynamic>),
        obstacleIds: (j['obstacle_ids'] as List<dynamic>).cast<String>(),
        steps: (j['steps'] as List<dynamic>)
            .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        highlights: ((j['highlights'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

/// A Sime Darby Property township or hub the app covers.
class Township {
  final String id;
  final String name;

  /// e.g. "Subang Jaya, Selangor"
  final String location;

  /// e.g. "Transit-oriented development"
  final String category;
  final LatLng center;

  /// Where routes start in the demo (the user's position).
  final Place start;

  /// Places people often head to here, shown under "Popular here".
  final List<Place> popular;

  const Township({
    required this.id,
    required this.name,
    required this.location,
    required this.category,
    required this.center,
    required this.start,
    required this.popular,
  });

  factory Township.fromJson(Map<String, dynamic> j) => Township(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String,
        category: j['category'] as String,
        center: _latLng(j['center'] as Map<String, dynamic>),
        start: Place.fromJson(j['start'] as Map<String, dynamic>),
        popular: (j['popular'] as List<dynamic>).map((p) => Place.fromJson(p as Map<String, dynamic>)).toList(),
      );
}

class Suggestion {
  final double kmFromRequested;
  final int extraMinutes;
  final List<String> reasons;

  const Suggestion({required this.kmFromRequested, required this.extraMinutes, required this.reasons});

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        kmFromRequested: (j['km_from_requested'] as num).toDouble(),
        extraMinutes: j['extra_minutes'] as int,
        reasons: (j['reasons'] as List<dynamic>).cast<String>(),
      );
}

class RoutePlan {
  final Place origin;
  final Place requested;
  final List<Obstacle> obstacles;
  final RouteOption stepFree;
  final RouteOption standard;
  final Suggestion? suggestion;

  const RoutePlan({
    required this.origin,
    required this.requested,
    required this.obstacles,
    required this.stepFree,
    required this.standard,
    this.suggestion,
  });

  RouteOption option(RouteKind k) => k == RouteKind.stepFree ? stepFree : standard;

  factory RoutePlan.fromJson(Map<String, dynamic> j) => RoutePlan(
        origin: Place.fromJson(j['origin'] as Map<String, dynamic>),
        requested: Place.fromJson(j['requested'] as Map<String, dynamic>),
        obstacles: (j['obstacles'] as List<dynamic>)
            .map((o) => Obstacle.fromJson(o as Map<String, dynamic>))
            .toList(),
        stepFree: RouteOption.fromJson(j['step_free'] as Map<String, dynamic>),
        standard: RouteOption.fromJson(j['standard'] as Map<String, dynamic>),
        suggestion: j['suggestion'] == null ? null : Suggestion.fromJson(j['suggestion'] as Map<String, dynamic>),
      );
}

// ---------------------------------------------------------------- profile

/// Who the route is planned for. Values match the web build's
/// `accessibilityNeeds` options.
enum MobilityNeed {
  wheelchair('wheelchair', 'Wheelchair user'),
  walkingAid('walking_aid', 'Cane, crutches or walker'),
  elderly('elderly', 'Can only walk short distances'),
  stroller('stroller', 'Pushing a stroller'),
  visuallyImpaired('visually_impaired', 'Blind or low vision'),
  hearingImpaired('hearing_impaired', 'Deaf or hard of hearing');

  final String apiValue;
  final String label;
  const MobilityNeed(this.apiValue, this.label);

  static MobilityNeed fromApi(String v) => values.firstWhere((n) => n.apiValue == v, orElse: () => wheelchair);
}

class RoutePrefs {
  final bool avoidStairs;
  final bool needsLift;
  final bool avoidSteepSlopes;
  final bool preferSheltered;

  const RoutePrefs({
    this.avoidStairs = true,
    this.needsLift = true,
    this.avoidSteepSlopes = true,
    this.preferSheltered = false,
  });

  RoutePrefs copyWith({bool? avoidStairs, bool? needsLift, bool? avoidSteepSlopes, bool? preferSheltered}) => RoutePrefs(
        avoidStairs: avoidStairs ?? this.avoidStairs,
        needsLift: needsLift ?? this.needsLift,
        avoidSteepSlopes: avoidSteepSlopes ?? this.avoidSteepSlopes,
        preferSheltered: preferSheltered ?? this.preferSheltered,
      );

  factory RoutePrefs.fromJson(Map<String, dynamic> j) => RoutePrefs(
        avoidStairs: j['avoid_stairs'] as bool,
        needsLift: j['needs_lift'] as bool,
        avoidSteepSlopes: j['avoid_steep_slopes'] as bool,
        preferSheltered: j['prefer_sheltered'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'avoid_stairs': avoidStairs,
        'needs_lift': needsLift,
        'avoid_steep_slopes': avoidSteepSlopes,
        'prefer_sheltered': preferSheltered,
      };
}

class EmergencyContact {
  final String id;
  final String name;
  final String relationship;
  final String phone;

  const EmergencyContact({required this.id, required this.name, required this.relationship, required this.phone});

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id'] as String,
        name: j['name'] as String,
        relationship: j['relationship'] as String,
        phone: j['phone'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'relationship': relationship, 'phone': phone};
}

class UserProfile {
  final String name;
  final String email;
  final Set<MobilityNeed> needs;
  final RoutePrefs prefs;

  /// Extra detail the user wants to share, e.g. "Powered wheelchair, 70 cm wide".
  final String needsNote;

  /// First contact is the primary one.
  final List<EmergencyContact> contacts;

  const UserProfile({
    required this.name,
    required this.email,
    required this.needs,
    required this.prefs,
    required this.needsNote,
    required this.contacts,
  });

  UserProfile copyWith({
    String? name,
    Set<MobilityNeed>? needs,
    RoutePrefs? prefs,
    String? needsNote,
    List<EmergencyContact>? contacts,
  }) =>
      UserProfile(
        name: name ?? this.name,
        email: email,
        needs: needs ?? this.needs,
        prefs: prefs ?? this.prefs,
        needsNote: needsNote ?? this.needsNote,
        contacts: contacts ?? this.contacts,
      );

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String,
        email: j['email'] as String,
        needs: (j['needs'] as List<dynamic>).map((n) => MobilityNeed.fromApi(n as String)).toSet(),
        prefs: RoutePrefs.fromJson(j['route_prefs'] as Map<String, dynamic>),
        needsNote: (j['needs_note'] as String?) ?? '',
        contacts: (j['emergency_contacts'] as List<dynamic>)
            .map((c) => EmergencyContact.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'needs': needs.map((n) => n.apiValue).toList(),
        'route_prefs': prefs.toJson(),
        'needs_note': needsNote,
        'emergency_contacts': contacts.map((c) => c.toJson()).toList(),
      };
}

// ---------------------------------------------------------------- rewards

class UserSummary {
  final int points;
  final int reports;
  final int confirmations;

  const UserSummary({required this.points, required this.reports, required this.confirmations});

  UserSummary copyWith({int? points, int? reports, int? confirmations}) => UserSummary(
        points: points ?? this.points,
        reports: reports ?? this.reports,
        confirmations: confirmations ?? this.confirmations,
      );

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
        points: j['points'] as int,
        reports: j['reports'] as int,
        confirmations: j['confirmations'] as int,
      );
}

enum RewardPartner {
  grab('grab', 'Grab'),
  touchNGo('touch_n_go', "Touch 'n Go"),
  rapidKL('rapid_kl', 'RapidKL');

  final String apiValue;
  final String label;
  const RewardPartner(this.apiValue, this.label);

  static RewardPartner fromApi(String v) => values.firstWhere((p) => p.apiValue == v, orElse: () => grab);
}

enum RewardCategory {
  rides('rides', 'Rides'),
  transit('transit', 'Public transport'),
  ewallet('ewallet', 'eWallet');

  final String apiValue;
  final String label;
  const RewardCategory(this.apiValue, this.label);

  static RewardCategory fromApi(String v) => values.firstWhere((c) => c.apiValue == v, orElse: () => rides);
}

class Reward {
  final String id;
  final RewardPartner partner;
  final RewardCategory category;
  final String title;
  final String description;
  final int cost;

  const Reward({
    required this.id,
    required this.partner,
    required this.category,
    required this.title,
    required this.description,
    required this.cost,
  });

  String get partnerName => partner.label;

  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
        id: j['id'] as String,
        partner: RewardPartner.fromApi(j['partner'] as String),
        category: RewardCategory.fromApi(j['category'] as String),
        title: j['title'] as String,
        description: j['description'] as String,
        cost: j['cost'] as int,
      );
}

/// A reward the user has redeemed, kept so they can find the code later.
class Voucher {
  final String code;
  final Reward reward;
  final DateTime redeemedAt;
  final DateTime expiresAt;

  const Voucher({required this.code, required this.reward, required this.redeemedAt, required this.expiresAt});

  factory Voucher.fromJson(Map<String, dynamic> j) => Voucher(
        code: j['code'] as String,
        reward: Reward.fromJson(j['reward'] as Map<String, dynamic>),
        redeemedAt: DateTime.parse(j['redeemed_at'] as String),
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
}

class RedeemResult {
  final Voucher voucher;
  final int pointsLeft;

  const RedeemResult({required this.voucher, required this.pointsLeft});

  factory RedeemResult.fromJson(Map<String, dynamic> j) => RedeemResult(
        voucher: Voucher.fromJson(j['voucher'] as Map<String, dynamic>),
        pointsLeft: j['points_left'] as int,
      );
}

/// One line in the points history. [amount] is negative for redemptions.
class PointsEntry {
  final String id;
  final String title;
  final String detail;
  final int amount;
  final DateTime at;

  const PointsEntry({required this.id, required this.title, required this.detail, required this.amount, required this.at});

  factory PointsEntry.fromJson(Map<String, dynamic> j) => PointsEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        detail: j['detail'] as String,
        amount: j['amount'] as int,
        at: DateTime.parse(j['at'] as String),
      );
}

// ---------------------------------------------------------------- formatting

/// "3h ago", "1d ago" — short relative time.
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return shortDate(t);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "15 Oct 2026"
String shortDate(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

/// "7:46 pm"
String clockTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
}

/// "Thu, 15 Oct 2026"
String longDate(DateTime t) => '${_days[t.weekday - 1]}, ${shortDate(t)}';
