import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_titlebar.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  testWidgets('shows app title and settings action by default', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: AppTitleBar(onActionPressed: () => pressed = true),
        ),
      ),
    );

    expect(find.text('ClearHear'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    expect(pressed, isTrue);
  });

  testWidgets('hides action icon when showActionIcon is false', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(
          body: AppTitleBar(showActionIcon: false),
        ),
      ),
    );

    expect(find.text('ClearHear'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });
}
