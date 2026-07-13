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
  static const errorRed = Color(0xFFE53935);

  static const historyBackground = Color(0xFFF7F5F2);
  static const cardSurface = Colors.white;
  static const chipBackground = Color(0xFFF6F6F6);
  static const cardShadow = Color(0x08000000);

  static const historyBadgeMeeting = Color(0xFFD1E9E4);
  static const historyBadgeHealth = Color(0xFFF8D7DA);
  static const historyBadgeLecture = Color(0xFFE8EAF6);

  static const cardBackground = Colors.white;
  static const title = Color(0xFF1A1A1A);
  static const body = Color(0xFF545454);
  static const muted = Color(0xFF7A7A7A);
  static const accent = Color(0xFF1C5B5B);

  static const Color gray = Color(0xFF6B7280);

  // Summary Card
  static const summaryPurple = Color(0xFF635BFF);
  static const summaryBackgroundStart = Color(0xFFF8F7FF);
  static const summaryBackgroundEnd = Color(0xFFF3F1FF);

  static const summaryBorder = Color(0xFFE5E7EB);

  // Text
  static const textDivider = Color(0xFF9CA3AF);

  // Private Badge
  static const privateBackground = Color(0xFFE8F7F3);
  static const privateGreen = Color(0xFF0F766E);
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
