import 'package:flutter/material.dart';

/// Design tokens and Material themes used across the application.
///
/// Screens should reach colors through [Theme.of] or the [SprichstColors]
/// extension. The named brand colors remain here for the few places where a
/// fixed Sprichst identity surface is intentional.
abstract final class SprichstTheme {
  static const ink = Color(0xFF13231C);
  static const forest = Color(0xFF1E5D45);
  static const moss = Color(0xFF70A77A);
  static const cream = Color(0xFFFFFCF5);
  static const sand = Color(0xFFF1EBDD);
  static const coral = Color(0xFFE87D5B);

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: forest,
      brightness: brightness,
      primary: isDark ? const Color(0xFF9BD4A6) : forest,
      secondary: isDark ? const Color(0xFFFFB59E) : coral,
      surface: isDark ? const Color(0xFF16201B) : Colors.white,
    );
    final primaryText = isDark ? const Color(0xFFF2F6F1) : ink;
    final secondaryText =
        isDark ? const Color(0xFFCAD4CD) : const Color(0xFF4C5A53);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF101713) : cream,
      textTheme: TextTheme(
        displaySmall:
            TextStyle(fontWeight: FontWeight.w800, color: primaryText),
        headlineSmall:
            TextStyle(fontWeight: FontWeight.w800, color: primaryText),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: primaryText),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: primaryText),
        bodyLarge: TextStyle(color: primaryText, height: 1.45),
        bodyMedium: TextStyle(color: secondaryText, height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const input = 16.0;
  static const card = 24.0;
}

extension SprichstColors on BuildContext {
  Color get brand => Theme.of(this).colorScheme.primary;
  Color get softSurface => Theme.of(this).colorScheme.secondaryContainer;
  Color get successSurface => Theme.of(this).colorScheme.primaryContainer;
  Color get dangerSurface => Theme.of(this).colorScheme.errorContainer;
}
