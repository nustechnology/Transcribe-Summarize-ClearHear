import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/summary_section.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  Future<void> pumpSection(
    WidgetTester tester, {
    required SummarySection section,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(body: section),
      ),
    );
  }

  testWidgets('shows summary content when available', (tester) async {
    await pumpSection(
      tester,
      section: const SummarySection(content: 'Key points discussed.'),
    );

    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.text('Key points discussed.'), findsOneWidget);
  });

  testWidgets('shows generating state while processing', (tester) async {
    await pumpSection(
      tester,
      section: const SummarySection(content: '', isProcessing: true),
    );

    expect(find.text('AI is summarizing your session...'), findsOneWidget);
  });

  testWidgets('shows failure message and retry', (tester) async {
    var retried = false;

    await pumpSection(
      tester,
      section: SummarySection(
        content: '',
        isFailed: true,
        failureMessage: 'Summary generation failed.',
        onRetry: () => retried = true,
      ),
    );

    expect(find.text('Summary generation failed.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('shows placeholder when empty and idle', (tester) async {
    await pumpSection(
      tester,
      section: const SummarySection(content: ''),
    );

    expect(
      find.text('No summary is available for this file.'),
      findsOneWidget,
    );
  });
}
