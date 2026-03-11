import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF0A2A66), // Deep Masonic Blue
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),

    useMaterial3: true,

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0A2A66),
      secondary: Color(0xFFE4C564), // Gold accent
    ),

    textTheme: const TextTheme(
      // Replaces headline1
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0A2A66),
      ),

      // Replaces headline6
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0A2A66),
      ),

      // Replaces bodyText1
      bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),

      // Replaces bodyText2
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A2A66),
      elevation: 2,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0A2A66),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF0A2A66), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF0A2A66)),
    ),
  );
}
