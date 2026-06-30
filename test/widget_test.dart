import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/home/home_widget.dart';

void main() {
  testWidgets('HomeView shows translated values', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const HomeView(),
      ),
    );

    expect(find.text('IDLE'), findsOneWidget);
    expect(
      find.text('Tap Start captioning to begin listening.'),
      findsOneWidget,
    );
    expect(find.text('SPEAKER 1'), findsNothing);
    expect(find.text('Start captioning'), findsOneWidget);
    expect(find.text('home_status_idle'), findsNothing);

    Get.reset();
  });
}
