import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/bottom_action_bar.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  testWidgets('invokes share and delete callbacks', (tester) async {
    Rect? shareOrigin;
    var deleted = false;

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: BottomActionBar(
            onShare: (origin) => shareOrigin = origin,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('Share text'), findsOneWidget);

    await tester.tap(find.text('Share text'));
    await tester.pump();
    expect(shareOrigin, isNotNull);

    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleted, isTrue);
  });

  testWidgets('disables actions while sharing or deleting', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: BottomActionBar(
            onShare: (_) {},
            onDelete: () {},
            isSharing: true,
            isDeleting: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
  });
}
