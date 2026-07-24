import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/caption_size_config.dart';
import 'package:transcribe_summarize_clearhear/shared/models/settings_model.dart';

void main() {
  group('SettingsModel', () {
    test('toMap / fromMap round-trip', () {
      const settings = SettingsModel(
        fontSize: 18,
        theme: 'dark',
        savingEnabled: false,
        keepScreenOn: true,
        powerSaver: true,
        updatedAt: 1700000000,
      );

      final restored = SettingsModel.fromMap(settings.toMap());

      expect(restored.fontSize, 18);
      expect(restored.theme, 'dark');
      expect(restored.savingEnabled, isFalse);
      expect(restored.keepScreenOn, isTrue);
      expect(restored.powerSaver, isTrue);
      expect(restored.updatedAt, 1700000000);
      expect(settings.toMap()['id'], 1);
      expect(settings.toMap()['saving_enabled'], 0);
    });

    test('fromMap clamps fontSize to CaptionSizeConfig bounds', () {
      final tooSmall = SettingsModel.fromMap({
        'font_size': 4,
        'updated_at': 1,
      });
      final tooLarge = SettingsModel.fromMap({
        'font_size': 99,
        'updated_at': 1,
      });

      expect(tooSmall.fontSize, CaptionSizeConfig.min);
      expect(tooLarge.fontSize, CaptionSizeConfig.max);
    });

    test('fromMap uses defaults for missing flags and theme', () {
      final restored = SettingsModel.fromMap({'updated_at': 42});

      expect(restored.theme, 'system');
      expect(restored.savingEnabled, isTrue);
      expect(restored.keepScreenOn, isFalse);
      expect(restored.powerSaver, isFalse);
      expect(restored.fontSize, CaptionSizeConfig.defaultSize);
    });

    test('copyWith overrides selected fields', () {
      const base = SettingsModel(updatedAt: 1, theme: 'light');
      final updated = base.copyWith(theme: 'dark', savingEnabled: false);

      expect(updated.theme, 'dark');
      expect(updated.savingEnabled, isFalse);
      expect(updated.updatedAt, 1);
      expect(updated.fontSize, base.fontSize);
    });

    test('defaults() uses CaptionSizeConfig.defaultSize', () {
      final defaults = SettingsModel.defaults();
      expect(defaults.fontSize, CaptionSizeConfig.defaultSize);
      expect(defaults.theme, 'system');
      expect(defaults.savingEnabled, isTrue);
    });
  });
}
