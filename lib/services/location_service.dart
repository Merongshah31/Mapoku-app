import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Device location access via the geolocator plugin.
///
/// Returns `null` instead of throwing so callers can fall back to the demo
/// map anchor when permission is denied or the service is off.
class LocationService {
  const LocationService();

  Future<LatLng?> currentLatLng() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}