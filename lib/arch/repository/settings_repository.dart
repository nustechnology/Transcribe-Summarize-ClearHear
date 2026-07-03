import '../../shared/models/settings_model.dart';

/// Abstract contract for the settings singleton (always id = 1).
abstract class SettingsRepository {
  /// Loads the single settings row; seeds defaults if the row is missing.
  Future<SettingsModel> loadSettings();

  /// Full upsert — replaces the singleton row atomically.
  Future<void> saveSettings(SettingsModel settings);

  /// Targeted update for theme only (avoids full read-modify-write).
  Future<void> updateTheme(String theme);

  /// Targeted update for font size only.
  Future<void> updateFontSize(double fontSize);

  /// Targeted update for the saving_enabled flag.
  Future<void> updateSavingEnabled({required bool enabled});
}
