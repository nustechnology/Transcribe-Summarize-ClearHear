import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/home/components/status_bar.dart';
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

  late HomeController controller;

  setUp(() {
    controller = HomeController(sherpaOnnxService: _FakeSherpaOnnxService());
    Get.put(controller);
  });

  tearDown(Get.reset);

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: StatusBar()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows Idle and font controls when not captioning',
      (tester) async {
    await pumpBar(tester);

    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('A–'), findsOneWidget);
    expect(find.text('A+'), findsOneWidget);
  });

  testWidgets('shows Listening while captioning', (tester) async {
    await pumpBar(tester);
    controller.isCaptioning.value = true;
    await tester.pump();

    expect(find.text('Listening'), findsOneWidget);
  });

  testWidgets('shows paused copy while paused', (tester) async {
    await pumpBar(tester);
    controller.isCaptioning.value = true;
    controller.isPaused.value = true;
    await tester.pump();

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Captioning paused'), findsOneWidget);
  });
}
