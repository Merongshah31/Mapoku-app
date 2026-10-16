import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants/app_config.dart';
import '../models/report.dart';

/// Location search backed by the public Nominatim service, matching the web
/// app's behaviour. Direct "lat, lng" input short-circuits the network call.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _headers = {'Accept': 'application/json'};

  static final RegExp _coordinatePattern =
      RegExp(r'^(-?\d+(?:\.\d+)?)\s*[,\s]\s*(-?\d+(?:\.\d+)?)$');

  /// Turns free text into coordinates, or throws a friendly error.
  Future<LatLng> geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const GeocodingException('Please enter a start and destination location.');
    }

    final direct = _parseCoordinates(trimmed);
    if (direct != null) return direct;

    final results = await search(trimmed, limit: 1);
    if (results.isEmpty) {
      throw const GeocodingException('No matching location found. Try a different area name.');
    }
    return results.first.position;
  }

  /// Returns up to [limit] suggestions for the given query.
  Future<List<PlaceSuggestion>> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    try {
      final uri = Uri.parse('${AppConfig.nominatimBaseUrl}/search').replace(
        queryParameters: {
          'format': 'jsonv2',
          'limit': limit.toString(),
          'q': trimmed,
        },
      );

      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body);
      if (data is! List) return const [];

      return data.whereType<Map>().map((item) {
        return PlaceSuggestion(
          label: item['display_name']?.toString() ?? '',
          position: LatLng(
            double.tryParse(item['lat']?.toString() ?? '') ?? 0,
            double.tryParse(item['lon']?.toString() ?? '') ?? 0,
          ),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  LatLng? _parseCoordinates(String input) {
    final match = _coordinatePattern.firstMatch(input);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}

class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}