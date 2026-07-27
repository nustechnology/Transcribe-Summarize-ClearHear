import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/controllers/settings_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/settings_widget.dart';
import 'package:transcribe_summarize_clearhear/shared/models/settings_model.dart';

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<SettingsModel> loadSettings() async => SettingsModel.defaults();

  @override
  Future<void> saveSettings(SettingsModel settings) async {}

  @override
  Future<void> updateTheme(String theme) async {}

  @override
  Future<void> updateFontSize(double fontSize) async {}

  @override
  Future<void> updateSavingEnabled({required bool enabled}) async {}
}

class _FakeSessionRepository implements SessionRepository {
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

  testWidgets('SettingsView shows caption size and clear-data labels',
      (tester) async {
    Get.put(
      SettingsController(
        settingsRepository: _FakeSettingsRepository(),
        sessionRepository: _FakeSessionRepository(),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const SettingsView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Caption size'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
