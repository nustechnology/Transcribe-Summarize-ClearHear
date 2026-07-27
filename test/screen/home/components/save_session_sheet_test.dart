import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/home/components/save_session_sheet.dart';
import 'package:transcribe_summarize_clearhear/screen/home/controllers/home_controller.dart';
import 'package:transcribe_summarize_clearhear/service/sherpa_onnx_service.dart';

class _FakeSherpaOnnxService extends SherpaOnnxService {
  @override
  Future<void> ensureModelReady() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  testWidgets('shows title field and discard/save actions', (tester) async {
    final controller = HomeController(
      sherpaOnnxService: _FakeSherpaOnnxService(),
    );
    Get.put(controller);
    controller.captioningElapsed.value = const Duration(seconds: 45);

    var discarded = false;
    String? savedTitle;

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: SaveSessionSheet(
            controller: controller,
            initialTitle: 'Morning standup',
            onDiscard: () => discarded = true,
            onSave: (title) async => savedTitle = title,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Save this session?'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Morning standup'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    expect(discarded, isTrue);

    await tester.enterText(find.byType(TextField), 'Renamed session');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(savedTitle, 'Renamed session');
  });
}
