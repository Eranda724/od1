import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get potatoCouchTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF8C42), // warm orange = energy + cozy
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFFF8F0), // warm cream background
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF8C42),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4A2C0A), // dark brown
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF4A2C0A),
        ),
      ),
    );
  }
}
