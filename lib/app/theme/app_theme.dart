import 'package:flutter/material.dart';

abstract final class SprichstTheme {
  static const ink = Color(0xFF13231C);
  static const forest = Color(0xFF1E5D45);
  static const moss = Color(0xFF70A77A);
  static const cream = Color(0xFFFFFCF5);
  static const sand = Color(0xFFF1EBDD);
  static const coral = Color(0xFFE87D5B);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          brightness: Brightness.light,
          primary: forest,
          secondary: coral,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontWeight: FontWeight.w800, color: ink),
          headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: ink),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
          bodyLarge: TextStyle(color: ink, height: 1.45),
          bodyMedium: TextStyle(color: Color(0xFF4C5A53), height: 1.4),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE4E8E2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE4E8E2)),
          ),
        ),
      );
}
