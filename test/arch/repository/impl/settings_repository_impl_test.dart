import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/settings_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/shared/caption_size_config.dart';
import 'package:transcribe_summarize_clearhear/shared/models/settings_model.dart';

import '../../../helpers/test_database.dart';

void main() {
  late TestDatabaseHarness harness;
  late SettingsRepositoryImpl settings;

  setUp(() async {
    harness = await TestDatabaseHarness.create();
    settings = SettingsRepositoryImpl(harness.databaseService);
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('loadSettings returns seeded defaults', () async {
    final loaded = await settings.loadSettings();
    expect(loaded.fontSize, CaptionSizeConfig.defaultSize);
    expect(loaded.theme, 'system');
    expect(loaded.savingEnabled, isTrue);
  });

  test('updateFontSize and updateSavingEnabled persist', () async {
    await settings.updateFontSize(18);
    await settings.updateSavingEnabled(enabled: false);

    final loaded = await settings.loadSettings();
    expect(loaded.fontSize, 18);
    expect(loaded.savingEnabled, isFalse);
  });

  test('saveSettings replaces singleton row', () async {
    await settings.saveSettings(
      const SettingsModel(
        fontSize: 14,
        theme: 'dark',
        savingEnabled: false,
        keepScreenOn: true,
        powerSaver: true,
        updatedAt: 99,
      ),
    );

    final loaded = await settings.loadSettings();
    expect(loaded.fontSize, 14);
    expect(loaded.theme, 'dark');
    expect(loaded.keepScreenOn, isTrue);
    expect(loaded.powerSaver, isTrue);
    expect(loaded.updatedAt, 99);
  });

  test('updateTheme persists theme string', () async {
    await settings.updateTheme('light');
    expect((await settings.loadSettings()).theme, 'light');
  });
}
