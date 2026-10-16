import 'package:latlong2/latlong.dart';

/// The obstacle categories the community can report.
///
/// Kept identical to the web app so data maps cleanly to the backend.
enum ObstacleType {
  noRamp('No ramp / stairs only', '⛔️'),
  liftBroken('Lift broken', '🛗'),
  pathBlocked('Path blocked', '🚧'),
  unevenSurface('Uneven surface', '🕳');

  const ObstacleType(this.label, this.icon);

  final String label;
  final String icon;

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