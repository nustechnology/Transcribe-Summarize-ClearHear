import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF0EFEC);
  static const primary = Color(0xFF1C5B5B);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textMuted = Color(0xFF9E9E9E);
  static const border = Color(0xFFE0E0E0);
  static const confidenceBlue = Color(0xFF1976D2);
  static const privacyBg = Color(0xFFE3F2FD);
  static const statusIdle = Color(0xFFB0B0B0);
  static const statusActive = Color(0xFF4CAF50);
  static const stopRed = Color(0xFFE66754);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      );
}
