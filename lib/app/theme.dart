import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// mapOKU palette — taken from the web build (unforgettablyz/mapoku) so both
/// platforms read as one product.
class Palette {
  static const moss = Color(0xFF346F4B); // brand, step-free route, primary actions
  static const mossPressed = Color(0xFF2A593C);
  static const mint = Color(0xFFE7EFE9); // selected / positive backgrounds
  static const page = Color(0xFFF0EEE7); // screen background
  static const surface = Color(0xFFFBFAF7); // grouped sections, sheets
  static const field = Color(0xFFF2F0E9); // inputs, inactive chips
  static const ink = Color(0xFF1E2B22); // text, balance block, origin pin
  static const secondary = Color(0xFF5B6660); // secondary text (5.7:1 on surface)
  static const tertiary = Color(0xFF6A6F68); // placeholders, inactive (4.5:1 on field)
  static const routeGrey = Color(0xFF8A8F88); // standard route line on the map (web value)
  static const amber = Color(0xFFC27A45); // obstacles only
  static const amberSoft = Color(0xFFF6EBD9);

  /// Amber dark enough for body text on [amberSoft] (5.5:1). The web build's
  /// #B8703B only reaches 3.3:1, too low for an accessibility app.
  static const amberText = Color(0xFF8A4F22);
  static const hairline = Color(0x1F1E2B22);

  /// Flagged reports and destructive actions only.
  static const danger = Color(0xFFA3352B);
  static const dangerSoft = Color(0xFFFBE9E7);
}

/// iOS Human Interface Guidelines type sizes. No custom font on purpose:
/// the system font (SF Pro) is what iPhone users read all day, and it
/// follows their Dynamic Type setting.
class TextStyles {
  static const title2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.ink, height: 1.2);
  static const title3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Palette.ink, height: 1.25);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Palette.ink, height: 1.3);
  static const body = TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: Palette.ink, height: 1.3);
  static const callout = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Palette.ink, height: 1.3);
  static const subhead = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Palette.secondary, height: 1.35);
  static const footnote = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Palette.secondary, height: 1.35);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Palette.secondary, height: 1.3);

  /// Digits that don't jiggle when values change (points, minutes).
  static const tabular = [FontFeature.tabularFigures()];
}

/// Corner radii by role, so hierarchy reads from shape too.
class Radii {
  static const sheet = 22.0;
  static const group = 14.0;
  static const control = 12.0;
  static const chip = 999.0;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.moss,
    primary: Palette.moss,
    surface: Palette.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.page,
    // iOS has no ink ripples; feedback comes from opacity + haptics instead.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Palette.moss),
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: Palette.moss,
      scaffoldBackgroundColor: Palette.page,
      barBackgroundColor: Palette.surface,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0x401E2B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
  );
}
