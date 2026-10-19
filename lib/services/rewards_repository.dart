import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_config.dart';
import '../models/profile.dart';
import '../models/reward.dart';

/// Local persistence for the points wallet and redemption history.
///
/// The backend does not yet expose a rewards endpoint, so the wallet lives on
/// device. This keeps the hackathon demo fully functional offline while the
/// catalogue and balance still feel like real state.
class RewardsRepository {
  static const _pointsKey = 'mapoku_points';
  static const _historyKey = 'mapoku_redemptions';
  static const _tokenKey = 'mapoku_token';
  static const _profileKey = 'mapoku_profile';

  Future<int> loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? AppConfig.startingPoints;
  }

  Future<void> savePoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, points);
  }

  Future<List<Redemption>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? const [];
    return raw
        .map((item) {
          try {
            return Redemption.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<Redemption>()
        .toList();
  }

  Future<void> saveHistory(List<Redemption> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKey,
      history.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return const UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Generates a simple voucher code for the redeemed reward.
  String generateCode(String brand) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[(random >> (i * 3)) % chars.length]);
    }
    final prefix = brand
        .replaceAll(RegExp('[^A-Za-z]'), '')
        .padRight(3, 'X')
        .substring(0, 3)
        .toUpperCase();
    return '$prefix-${buffer.toString()}';
  }
}
