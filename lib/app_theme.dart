import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get potatoCouchTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFC72C), // Bright Golden Yellow
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4ECE1), // Warm cream background
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFC72C),
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC72C),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 2), // Adds retro black border to buttons
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFC72C), // Golden Yellow
          shadows: [
            Shadow(offset: Offset(-2, -2), color: Colors.black),
            Shadow(offset: Offset(2, -2), color: Colors.black),
            Shadow(offset: Offset(2, 2), color: Colors.black),
            Shadow(offset: Offset(-2, 2), color: Colors.black),
          ],
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
