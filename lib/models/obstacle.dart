import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// The obstacle categories the community can report.
///
/// The first four match the web app so existing data maps to the backend.
enum ObstacleType {
  noRamp('No ramp / stairs only', Icons.stairs),
  liftBroken('Lift broken', Icons.elevator),
  pathBlocked('Path blocked', Icons.block, blocksEveryone: true),
  unevenSurface('Uneven surface', Icons.terrain),
  constructionWorks(
    'Construction works',
    Icons.construction,
    blocksEveryone: true,
  ),
  vehicleBlocking('Vehicle blocking the way', Icons.directions_car),
  highKerb('No kerb ramp / high kerb', Icons.height),
  steepSlope('Steep slope', Icons.trending_up),
  narrowPath('Path too narrow', Icons.compare_arrows),
  slipperyFloor('Wet or slippery floor', Icons.water_drop_outlined),
  heavyDoor('Door hard to open', Icons.door_front_door_outlined),
  noTactile('Missing tactile paving', Icons.blind),
  poorLighting('Poor lighting', Icons.lightbulb_outline),
  okuBayTaken('OKU bay or toilet unavailable', Icons.accessible),
  other('Something else', Icons.help_outline);

  const ObstacleType(this.label, this.icon, {this.blocksEveryone = false});

  final String label;
  final IconData icon;

  /// True when nobody can get past (not just wheelchair users), so even a
  /// standard walking route should avoid it.
  final bool blocksEveryone;

  static ObstacleType fromLabel(String? label) {
    return ObstacleType.values.firstWhere(
      (type) => type.label == label,
      orElse: () => ObstacleType.pathBlocked,
    );
  }
}

/// A reported accessibility obstacle shown on the map and in the feed.
class Obstacle {
  const Obstacle({
    required this.id,
    required this.type,
    required this.position,
    this.location = '',
    this.description = '',
    this.ago = 'just now',
    this.confirms = 0,
    this.clearances = 0,
  });

  final String id;
  final ObstacleType type;
  final LatLng position;
  final String location;
  final String description;
  final String ago;
  final int confirms;
  final int clearances;

  Obstacle copyWith({
    int? confirms,
    int? clearances,
    String? ago,
  }) {
    return Obstacle(
      id: id,
      type: type,
      position: position,
      location: location,
      description: description,
      ago: ago ?? this.ago,
      confirms: confirms ?? this.confirms,
      clearances: clearances ?? this.clearances,
    );
  }

  /// Best-effort parser for the backend obstacle shape.
  factory Obstacle.fromJson(Map<String, dynamic> json) {
    final lat = _asDouble(json['latitude'] ?? json['lat'] ?? json['coords']?['lat']);
    final lng = _asDouble(json['longitude'] ?? json['lng'] ?? json['coords']?['lng']);

    return Obstacle(
      id: (json['_id'] ?? json['id'] ?? 'obstacle-${lat}_$lng').toString(),
      type: ObstacleType.fromLabel(json['type']?.toString()),
      position: LatLng(lat ?? 0, lng ?? 0),
      location: (json['location'] ?? json['address'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      ago: (json['ago'] ?? 'recently').toString(),
      confirms: _asInt(json['confirmations'] ?? json['confirms'] ?? json['upvotes']),
      clearances: _asInt(json['clearances'] ?? json['downvotes']),
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}