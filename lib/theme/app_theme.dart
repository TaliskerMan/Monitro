// Monitro App Theme — Dark, modern, monitoring aesthetic
import 'package:flutter/material.dart';

/// Central theme repository defining the visual style of Monitro.
///
/// Implements a dark mode dashboard aesthetic with neon green, cyan, and amber
/// highlights suitable for high-density charts and system statuses.
class AppTheme {
  AppTheme._();

  // Brand colors

  /// Bright cyan accent color used for highlighted headers, select items, and gauges.
  static const Color accent = Color(0xFF00E5FF);

  /// Vibrant green indicator color for successful operations, active daemons, and healthy states.
  static const Color success = Color(0xFF00C853);

  /// Amber status color warning of moderate system loads or minor connection issues.
  static const Color warning = Color(0xFFFFAB00);

  /// Intense red styling marking errors, failed services, or severe resource limits.
  static const Color danger = Color(0xFFFF5252);

  /// Deep pitch black background color matched to GitHub dark mode palettes.
  static const Color surface = Color(0xFF0D1117);

  /// Slightly lighter surface color to group card components and panel containers.
  static const Color surfaceAlt = Color(0xFF161B22);

  /// Dark grey color defining borders, grids, and divider lines.
  static const Color border = Color(0xFF30363D);

  /// Primary white text color for high contrast labels.
  static const Color onSurface = Color(0xFFE6EDF3);

  /// Muted grey text color for subtitles, timestamps, and secondary captions.
  static const Color muted = Color(0xFF8B949E);

  /// Dark material theme configurations customized for system monitoring telemetry.
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: surface,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: surfaceAlt,
          error: danger,
          onSurface: onSurface,
        ),
        cardTheme: CardThemeData(
          color: surfaceAlt,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: onSurface,
          elevation: 0,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF0A0E13),
          selectedIconTheme: IconThemeData(color: accent, size: 22),
          unselectedIconTheme:
              IconThemeData(color: Color(0xFF6E7681), size: 22),
          selectedLabelTextStyle: TextStyle(
              color: accent, fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelTextStyle:
              TextStyle(color: Color(0xFF6E7681), fontSize: 13),
          indicatorColor: Color(0xFF1C2A3A),
        ),
        textTheme: const TextTheme(
          headlineSmall:
              TextStyle(color: onSurface, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: onSurface),
          bodySmall: TextStyle(color: muted),
        ),
        dividerColor: border,
      );
}
