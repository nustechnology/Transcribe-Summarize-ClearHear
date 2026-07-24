import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/controllers/settings_controller.dart';
import 'package:transcribe_summarize_clearhear/shared/caption_size_config.dart';
import 'package:transcribe_summarize_clearhear/shared/models/settings_model.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    SettingsModel? initial,
    this.failUpdateFontSize = false,
    this.failUpdateSaving = false,
  }) : _settings = initial ??
            const SettingsModel(
              fontSize: CaptionSizeConfig.defaultSize,
              updatedAt: 1,
            );

  SettingsModel _settings;
  final bool failUpdateFontSize;
  final bool failUpdateSaving;
  final List<double> fontSizeUpdates = [];
  final List<bool> savingUpdates = [];
  final List<SettingsModel> saved = [];

  @override
  Future<SettingsModel> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    _settings = settings;
    saved.add(settings);
  }

  @override
  Future<void> updateTheme(String theme) async {}

  @override
  Future<void> updateFontSize(double fontSize) async {
    if (failUpdateFontSize) throw Exception('font size failed');
    fontSizeUpdates.add(fontSize);
    _settings = _settings.copyWith(fontSize: fontSize);
  }

  @override
  Future<void> updateSavingEnabled({required bool enabled}) async {
    if (failUpdateSaving) throw Exception('saving failed');
    savingUpdates.add(enabled);
    _settings = _settings.copyWith(savingEnabled: enabled);
  }
}

class _FakeSessionRepository implements SessionRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAllSessions() async {
    deleteAllCalls += 1;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  Future<SettingsController> buildController({
    _FakeSettingsRepository? settings,
    _FakeSessionRepository? sessions,
  }) async {
    final controller = SettingsController(
      settingsRepository: settings ?? _FakeSettingsRepository(),
      sessionRepository: sessions ?? _FakeSessionRepository(),
    );
    Get.put(controller);
    await Future<void>.delayed(Duration.zero);
    return controller;
  }

  test('loadSettings populates caption size and save flag', () async {
    final settings = _FakeSettingsRepository(
      initial: const SettingsModel(
        fontSize: 18,
        savingEnabled: false,
        updatedAt: 1,
      ),
    );
    final controller = await buildController(settings: settings);

    expect(controller.captionSize.value, 18);
    expect(controller.saveTranscripts.value, isFalse);
    expect(controller.isLoading.value, isFalse);
  });

  test('increase and decreaseCaptionSize clamp at bounds', () async {
    final settings = _FakeSettingsRepository(
      initial: const SettingsModel(
        fontSize: CaptionSizeConfig.max - CaptionSizeConfig.step,
        updatedAt: 1,
      ),
    );
    final controller = await buildController(settings: settings);

    await controller.increaseCaptionSize();
    expect(controller.captionSize.value, CaptionSizeConfig.max);
    await controller.increaseCaptionSize();
    expect(controller.captionSize.value, CaptionSizeConfig.max);

    while (controller.captionSize.value > CaptionSizeConfig.min) {
      await controller.decreaseCaptionSize();
    }
    expect(controller.captionSize.value, CaptionSizeConfig.min);
    await controller.decreaseCaptionSize();
    expect(controller.captionSize.value, CaptionSizeConfig.min);
  });

  test('setSaveTranscripts rolls back when repository throws', () async {
    final settings = _FakeSettingsRepository(failUpdateSaving: true);
    final controller = await buildController(settings: settings);

    await controller.setSaveTranscripts(false);

    expect(controller.saveTranscripts.value, isTrue);
  });

  test('_setCaptionSize rolls back when repository throws', () async {
    final settings = _FakeSettingsRepository(failUpdateFontSize: true);
    final controller = await buildController(settings: settings);
    final previous = controller.captionSize.value;

    await controller.increaseCaptionSize();

    expect(controller.captionSize.value, previous);
  });

  test('clearAllData deletes sessions and restores defaults', () async {
    final settings = _FakeSettingsRepository(
      initial: const SettingsModel(
        fontSize: 20,
        savingEnabled: false,
        updatedAt: 1,
      ),
    );
    final sessions = _FakeSessionRepository();
    final controller = await buildController(
      settings: settings,
      sessions: sessions,
    );

    await controller.clearAllData();

    expect(sessions.deleteAllCalls, 1);
    expect(settings.saved, hasLength(1));
    expect(controller.captionSize.value, CaptionSizeConfig.defaultSize);
    expect(controller.saveTranscripts.value, isTrue);
    expect(controller.isClearing.value, isFalse);
  });
}
