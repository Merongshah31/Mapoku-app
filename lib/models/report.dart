import 'package:latlong2/latlong.dart';

/// Verification state of a report as shown in the "My Reports" tab.
enum ReportStatus {
  pending('Pending verification', 0xFFB26A00, 0xFFFFF4E5),
  verified('Verified', 0xFF2E7D32, 0xFFE6F2E7),
  flagged('Flagged', 0xFFC62828, 0xFFFBE9E7);

  const ReportStatus(this.label, this.textColorValue, this.backgroundValue);

  final String label;
  final int textColorValue;
  final int backgroundValue;
}

/// A single report row shown in the Reports screen.
class Report {
  const Report({
    required this.id,
    required this.type,
    this.icon = '📍',
    this.location = '',
    this.description = '',
    this.imagePath,
    required this.createdAt,
    this.status = ReportStatus.pending,
    this.confirmations = 0,
    this.clearances = 0,
    this.flagReason,
    this.isMine = false,
    this.position,
  });

  final String id;
  final String type;
  final String icon;
  final String location;
  final String description;
  final String? imagePath;
  final DateTime createdAt;
  final ReportStatus status;
  final int confirmations;
  final int clearances;
  final String? flagReason;
  final bool isMine;

  /// Where the obstacle is, when known (shown on the report detail map).
  final LatLng? position;

  Report copyWith({int? confirmations, int? clearances, bool? isMine}) {
    return Report(
      id: id,
      type: type,
      icon: icon,
      location: location,
      description: description,
      imagePath: imagePath,
      createdAt: createdAt,
      status: status,
      confirmations: confirmations ?? this.confirmations,
      clearances: clearances ?? this.clearances,
      flagReason: flagReason,
      isMine: isMine ?? this.isMine,
      position: position,
    );
  }
}

/// A geocoding suggestion returned by Nominatim.
class PlaceSuggestion {
  const PlaceSuggestion({required this.label, required this.position});

  final String label;
  final LatLng position;
}
