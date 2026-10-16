import 'package:flutter/material.dart';

/// mapOKU brand palette.
///
/// The values mirror the original web design system so the Flutter app keeps
/// the same identity, then get tuned toward an Apple-like, calm and legible
/// accessibility feel (soft surfaces, a single confident accent, gentle lines).
class AppColors {
  const AppColors._();

  // Brand greens
  static const Color primary = Color(0xFF346F4B);
  static const Color primaryDark = Color(0xFF2A593C);
  static const Color forest = Color(0xFF1E2B22);
  static const Color mint = Color(0xFFE7EFE9);
  static const Color mintBorder = Color(0xFFCFE0D5);
  static const Color sage = Color(0xFF4A785B);

  // Surfaces
  static const Color background = Color(0xFFF0EEE7);
  static const Color surface = Color(0xFFFBFAF7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color field = Color(0xFFF2F0E9);

  // Accents
  static const Color accent = Color(0xFFC27A45);
  static const Color accentSoft = Color(0xFFF6EBD9);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFBE9E7);
  static const Color success = Color(0xFF2E7D32);
  static const Color successSoft = Color(0xFFE6F2E7);

  // Text
  static const Color textPrimary = Color(0xFF1E2B22);
  static const Color textSecondary = Color(0xFF68736B);
  static const Color textTertiary = Color(0xFF9AA39C);

  // Lines
  static const Color border = Color(0xFFE3E1D9);
  static const Color divider = Color(0xFFEFEDE6);

  // ---------------------------------------------------------------------------
  // Sime Darby Property brand (used by the 3D demo hubs)
  // ---------------------------------------------------------------------------

  static const Color sdpRed = Color(0xFFE31837);
  static const Color sdpRedDark = Color(0xFFB01229);
  static const Color sdpCharcoal = Color(0xFF1E1E1E);
  static const Color sdpCharcoalSoft = Color(0xFF2B2B2B);
  static const Color sdpGrey = Color(0xFFF4F4F4);
  static const Color sdpGreyMid = Color(0xFF8C8C8C);

  /// Pedestrian route colour in standard mode.
  static const Color routeStandard = Color(0xFFE0E0E0);

  /// Glowing OKU / wheelchair route colour.
  static const Color routeAccessible = Color(0xFF37E07A);

  /// Simulated construction barrier.
  static const Color construction = Color(0xFFFFB020);
}