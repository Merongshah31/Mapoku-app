/// Central configuration for mapOKU.
///
/// The hackathon build blends guaranteed demo data with live endpoints:
/// OpenStreetMap tiles, Nominatim geocoding, device location and the existing
/// mapOKU backend are real; the route/obstacle scenario and reward catalogue
/// are hardcoded so a demo never fails on stage.
class AppConfig {
  const AppConfig._();

  /// Existing mapOKU backend (same base URL the React app uses).
  static const String apiBaseUrl = 'https://map-oku-backend.vercel.app';

  /// Public geocoding service used by the web app.
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// OpenStreetMap raster tiles.
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';

  // Demo map anchors (Kuala Lumpur).
  static const double defaultLat = 3.134;
  static const double defaultLng = 101.686;
  static const double defaultZoom = 13.0;
  static const double detailZoom = 16.0;

  /// Points awarded when a community member reports an obstacle.
  static const int pointsPerReport = 10;

  /// Points awarded once other members confirm the report.
  static const int pointsPerConfirmation = 40;

  /// Starting balance for the demo so judges can redeem immediately.
  static const int startingPoints = 620;
}