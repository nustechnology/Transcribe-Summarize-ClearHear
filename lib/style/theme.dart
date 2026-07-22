import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF0EFEC);
  static const primary = Color(0xFF1C5B5B);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF5F6368);
  static const textMuted = Color(0xFF7A7A7A);
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
  static const body = Color(0xFF3F3F46);
  static const muted = Color(0xFF6B7280);
  static const accent = Color(0xFF1C5B5B);

  static const Color gray = Color(0xFF6B7280);

  // Summary Card
  static const summaryPurple = Color(0xFF635BFF);
  static const summaryBackgroundStart = Color(0xFFF8F7FF);
  static const summaryBackgroundEnd = Color(0xFFF3F1FF);

  static const summaryBorder = Color(0xFFE5E7EB);

  // Text
  static const textDivider = Color(0xFF6B7280);

  // Private Badge
  static const privateBackground = Color(0xFFE8F7F3);
  static const privateGreen = Color(0xFF0F766E);

  /// Distinct colors for speaker avatars / labels (cycled by speaker id).
  static const speakerPalette = <Color>[
    Color(0xFF1C5B5B), // teal
    Color(0xFFC45C26), // terracotta
    Color(0xFF3F51B5), // indigo
    Color(0xFF7B1FA2), // purple
    Color(0xFF00897B), // green-teal
    Color(0xFFD81B60), // pink
    Color(0xFF546E7A), // blue-grey
    Color(0xFFEF6C00), // orange
    Color(0xFF00695C), // dark teal
    Color(0xFF5C6BC0), // soft indigo
    Color(0xFF8D6E63), // brown
    Color(0xFF039BE5), // light blue
  ];

  /// Stable color for a speaker label (same label → same color).
  static Color colorForSpeaker(String? label) {
    final trimmed = label?.trim() ?? '';
    if (trimmed.isEmpty) return primary;

    final numbered =
        RegExp(r'^Speaker\s+(\d+)$', caseSensitive: false).firstMatch(trimmed);
    if (numbered != null) {
      final index = (int.parse(numbered.group(1)!) - 1) % speakerPalette.length;
      return speakerPalette[index < 0 ? 0 : index];
    }

    return speakerPalette[trimmed.hashCode.abs() % speakerPalette.length];
  }
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
