import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants/app_config.dart';
import '../models/obstacle.dart';

/// Thin client for the existing mapOKU backend.
///
/// Mirrors `src/api/mapokuApi.js` so the Flutter app can talk to exactly the
/// same endpoints. Every call is wrapped so demo screens can fall back to
/// hardcoded data when the backend is unreachable.
class MapokuApiService {
  MapokuApiService({http.Client? client, this.baseUrl = AppConfig.apiBaseUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalized');
    if (params == null || params.isEmpty) return uri;
    return uri.replace(
      queryParameters: params.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? params,
  }) async {
    final request = http.Request(method, _uri(path, params));
    request.headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request).timeout(const Duration(seconds: 12));
    final response = await http.Response.fromStream(streamed);
    final text = response.body;
    final data = text.isEmpty ? null : _decode(text);

    if (response.statusCode >= 400) {
      final message = data is Map ? (data['message'] ?? data['error']) : null;
      throw MapokuApiException(message?.toString() ?? 'Request failed (${response.statusCode})');
    }
    return data;
  }

  dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  // ---------------------------------------------------------------------------
  // Health & auth
  // ---------------------------------------------------------------------------

  Future<bool> healthCheck() async {
    try {
      await _request('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final data = await _request('/api/v1/users/login', method: 'POST', body: {
      'email': email,
      'password': password,
    });
    return _asMap(data);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await _request('/api/v1/users/register', method: 'POST', body: {
      'username': username,
      'email': email,
      'password': password,
    });
    return _asMap(data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  // ---------------------------------------------------------------------------
  // Obstacles
  // ---------------------------------------------------------------------------

  Future<List<Obstacle>> getObstaclesInView({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final data = await _request('/api/v1/obstacles', params: {
      'minLat': minLat,
      'minLng': minLng,
      'maxLat': maxLat,
      'maxLng': maxLng,
    });
    return _asList(data)
        .whereType<Map>()
        .map((item) => Obstacle.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> submitObstacle({
    required ObstacleType type,
    required LatLng position,
    String? description,
    String? imagePath,
  }) async {
    await _request('/api/v1/obstacles', method: 'POST', body: {
      'type': type.label,
      'latitude': position.latitude,
      'longitude': position.longitude,
      if (description != null && description.isNotEmpty) 'description': description,
      'image': ?imagePath,
    });
  }

  Future<void> upvoteObstacle(String id) =>
      _request('/api/v1/obstacles/$id/upvote', method: 'PUT');

  Future<void> downvoteObstacle(String id) =>
      _request('/api/v1/obstacles/$id/downvote', method: 'PUT');

  // ---------------------------------------------------------------------------
  // Routes & weather
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getAccessibleRoute({
    required LatLng start,
    required LatLng end,
    String accessibilityNeeds = 'wheelchair',
  }) async {
    final data = await _request('/api/v1/routes/accessible', params: {
      'startLat': start.latitude,
      'startLng': start.longitude,
      'endLat': end.latitude,
      'endLng': end.longitude,
      'accessibilityNeeds': accessibilityNeeds,
    });
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getCurrentWeather(double lat, double lng) async {
    final data = await _request('/api/v1/weather/current', params: {'lat': lat, 'lng': lng});
    return _asMap(data);
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final nested = data['data'] ?? data['obstacles'] ?? data['items'];
      if (nested is List) return nested;
    }
    return const [];
  }
}

class MapokuApiException implements Exception {
  MapokuApiException(this.message);

  final String message;

  @override
  String toString() => message;
}