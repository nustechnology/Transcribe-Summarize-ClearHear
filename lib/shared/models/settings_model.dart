import 'package:transcribe_summarize_clearhear/shared/caption_size_config.dart';

/// Domain model for the settings singleton row (always id = 1).
class SettingsModel {
  const SettingsModel({
    this.fontSize = CaptionSizeConfig.defaultSize,
    this.theme = 'system',
    this.savingEnabled = true,
    this.keepScreenOn = false,
    this.powerSaver = false,
    required this.updatedAt,
  });

  final double fontSize;

  /// One of: 'light', 'dark', 'system'.
  final String theme;

  final bool savingEnabled;
  final bool keepScreenOn;
  final bool powerSaver;

  /// Unix epoch (seconds).
  final int updatedAt;

  SettingsModel copyWith({
    double? fontSize,
    String? theme,
    bool? savingEnabled,
    bool? keepScreenOn,
    bool? powerSaver,
    int? updatedAt,
  }) {
    return SettingsModel(
      fontSize: fontSize ?? this.fontSize,
      theme: theme ?? this.theme,
      savingEnabled: savingEnabled ?? this.savingEnabled,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      powerSaver: powerSaver ?? this.powerSaver,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'font_size': fontSize,
      'theme': theme,
      'saving_enabled': savingEnabled ? 1 : 0,
      'keep_screen_on': keepScreenOn ? 1 : 0,
      'power_saver': powerSaver ? 1 : 0,
      'updated_at': updatedAt,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      fontSize: ((map['font_size'] as num?)?.toDouble() ??
              CaptionSizeConfig.defaultSize)
          .clamp(CaptionSizeConfig.min, CaptionSizeConfig.max),
      theme: map['theme'] as String? ?? 'system',
      savingEnabled: (map['saving_enabled'] as int? ?? 1) == 1,
      keepScreenOn: (map['keep_screen_on'] as int? ?? 0) == 1,
      powerSaver: (map['power_saver'] as int? ?? 0) == 1,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// Default settings used when the table row doesn't exist yet.
  factory SettingsModel.defaults() {
    return SettingsModel(
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  String toString() =>
      'SettingsModel(theme: $theme, fontSize: $fontSize, savingEnabled: $savingEnabled)';
}
