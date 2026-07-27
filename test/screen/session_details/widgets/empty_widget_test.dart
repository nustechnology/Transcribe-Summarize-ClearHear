import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/empty_widget.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  testWidgets('shows message and invokes retry', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: EmptyState(
            message: 'Something went wrong',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
