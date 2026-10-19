/// Mobility and sensory needs a member can say apply to them.
enum MobilityNeed {
  wheelchair('Wheelchair user'),
  walkingAid('Walking aid or crutches'),
  elderly('Older adult'),
  stroller('Pushing a stroller'),
  visuallyImpaired('Visual impairment'),
  hearingImpaired('Hearing impairment');

  const MobilityNeed(this.label);

  final String label;

  static MobilityNeed? fromName(String? name) {
    for (final need in values) {
      if (need.name == name) return need;
    }
    return null;
  }
}

/// How routes should be planned for this member.
class RoutePrefs {
  const RoutePrefs({
    this.avoidStairs = true,
    this.needsLift = false,
    this.avoidSteepSlopes = false,
    this.preferSheltered = true,
  });

  final bool avoidStairs;
  final bool needsLift;
  final bool avoidSteepSlopes;
  final bool preferSheltered;

  RoutePrefs copyWith({
    bool? avoidStairs,
    bool? needsLift,
    bool? avoidSteepSlopes,
    bool? preferSheltered,
  }) {
    return RoutePrefs(
      avoidStairs: avoidStairs ?? this.avoidStairs,
      needsLift: needsLift ?? this.needsLift,
      avoidSteepSlopes: avoidSteepSlopes ?? this.avoidSteepSlopes,
      preferSheltered: preferSheltered ?? this.preferSheltered,
    );
  }

  Map<String, dynamic> toJson() => {
    'avoidStairs': avoidStairs,
    'needsLift': needsLift,
    'avoidSteepSlopes': avoidSteepSlopes,
    'preferSheltered': preferSheltered,
  };

  factory RoutePrefs.fromJson(Map<String, dynamic> json) => RoutePrefs(
    avoidStairs: json['avoidStairs'] as bool? ?? true,
    needsLift: json['needsLift'] as bool? ?? false,
    avoidSteepSlopes: json['avoidSteepSlopes'] as bool? ?? false,
    preferSheltered: json['preferSheltered'] as bool? ?? true,
  );
}

/// Someone to call in an emergency. mapOKU never contacts them itself.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String id;
  final String name;
  final String relationship;
  final String phone;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'phone': phone,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        relationship: json['relationship']?.toString() ?? 'Other',
        phone: json['phone']?.toString() ?? '',
      );
}

/// The member's accessibility profile, stored on the device.
class UserProfile {
  const UserProfile({
    this.name = '',
    this.needs = const <MobilityNeed>{},
    this.needsNote = '',
    this.prefs = const RoutePrefs(),
    this.contacts = const <EmergencyContact>[],
  });

  /// Empty means "use the signed-in name".
  final String name;
  final Set<MobilityNeed> needs;
  final String needsNote;
  final RoutePrefs prefs;
  final List<EmergencyContact> contacts;

  UserProfile copyWith({
    String? name,
    Set<MobilityNeed>? needs,
    String? needsNote,
    RoutePrefs? prefs,
    List<EmergencyContact>? contacts,
  }) {
    return UserProfile(
      name: name ?? this.name,
      needs: needs ?? this.needs,
      needsNote: needsNote ?? this.needsNote,
      prefs: prefs ?? this.prefs,
      contacts: contacts ?? this.contacts,
    );
  }

  /// True when routes should avoid stairs by default.
  bool get wantsStepFree =>
      prefs.avoidStairs ||
      needs.any(
        (need) =>
            need == MobilityNeed.wheelchair ||
            need == MobilityNeed.walkingAid ||
            need == MobilityNeed.elderly ||
            need == MobilityNeed.stroller,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'needs': [for (final need in needs) need.name],
    'needsNote': needsNote,
    'prefs': prefs.toJson(),
    'contacts': [for (final contact in contacts) contact.toJson()],
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawNeeds = json['needs'];
    final rawContacts = json['contacts'];
    return UserProfile(
      name: json['name']?.toString() ?? '',
      needs: {
        if (rawNeeds is List)
          for (final item in rawNeeds)
            if (MobilityNeed.fromName(item?.toString()) != null)
              MobilityNeed.fromName(item.toString())!,
      },
      needsNote: json['needsNote']?.toString() ?? '',
      prefs: json['prefs'] is Map<String, dynamic>
          ? RoutePrefs.fromJson(json['prefs'] as Map<String, dynamic>)
          : const RoutePrefs(),
      contacts: [
        if (rawContacts is List)
          for (final item in rawContacts)
            if (item is Map<String, dynamic>) EmergencyContact.fromJson(item),
      ],
    );
  }
}
