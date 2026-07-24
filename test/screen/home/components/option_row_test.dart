import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/home/components/option_row.dart';
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

  testWidgets('shows medium confidence when idle', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: OptionsRow()),
      ),
    );
    await tester.pump();

    expect(find.text('English (US)'), findsOneWidget);
    expect(find.text('Confidence:'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
  });

  testWidgets('shows high confidence while listening', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: OptionsRow()),
      ),
    );
    controller.isCaptioning.value = true;
    await tester.pump();

    expect(find.text('High'), findsOneWidget);
    expect(find.text('Medium'), findsNothing);
  });
}
