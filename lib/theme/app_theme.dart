// Monitro App Theme — Dark, modern, monitoring aesthetic
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color accent     = Color(0xFF00E5FF);   // cyan
  static const Color success    = Color(0xFF00C853);   // green
  static const Color warning    = Color(0xFFFFAB00);   // amber
  static const Color danger     = Color(0xFFFF5252);   // red
  static const Color surface    = Color(0xFF0D1117);   // GitHub dark bg
  static const Color surfaceAlt = Color(0xFF161B22);   // cards
  static const Color border     = Color(0xFF30363D);   // subtle borders
  static const Color onSurface  = Color(0xFFE6EDF3);   // primary text
  static const Color muted      = Color(0xFF8B949E);   // secondary text

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surface,
    colorScheme: const ColorScheme.dark(
      primary:   accent,
      secondary: accent,
      surface:   surfaceAlt,
      error:     danger,
      onPrimary: Color(0xFF000000),
      onSurface: onSurface,
    ),
    cardTheme: CardThemeData(
      color: surfaceAlt,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border, width: 1),
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
      unselectedIconTheme: IconThemeData(color: Color(0xFF6E7681), size: 22),
      selectedLabelTextStyle: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelTextStyle: TextStyle(color: Color(0xFF6E7681), fontSize: 13),
      indicatorColor: Color(0xFF1C2A3A),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
      titleMedium:   TextStyle(color: onSurface, fontWeight: FontWeight.w600),
      bodyMedium:    TextStyle(color: onSurface),
      bodySmall:     TextStyle(color: muted),
    ),
    dividerColor: border,
  );
}
