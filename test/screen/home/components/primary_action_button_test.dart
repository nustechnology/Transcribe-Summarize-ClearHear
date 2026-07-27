import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/home/components/primary_action_button.dart';
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

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: PrimaryActionButton()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows start captioning when idle and model ready',
      (tester) async {
    await pumpButton(tester);
    controller.isAsrModelReady.value = true;
    controller.isAsrModelLoading.value = false;
    await tester.pump();

    expect(find.text('Start captioning'), findsOneWidget);
  });

  testWidgets('shows stop and pause while captioning', (tester) async {
    await pumpButton(tester);
    controller.isAsrModelReady.value = true;
    controller.isAsrModelLoading.value = false;
    controller.isCaptioning.value = true;
    await tester.pump();

    expect(find.text('Stop captioning'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('shows resume and stop while paused', (tester) async {
    await pumpButton(tester);
    controller.isCaptioning.value = true;
    controller.isPaused.value = true;
    await tester.pump();

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Stop captioning'), findsOneWidget);
  });

  testWidgets('shows loading model label while ASR loads', (tester) async {
    await pumpButton(tester);
    controller.isAsrModelLoading.value = true;
    controller.isAsrModelReady.value = false;
    await tester.pump();

    expect(find.textContaining('Loading model'), findsOneWidget);
  });
}
