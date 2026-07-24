import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_loading.dart';

void main() {
  testWidgets('renders rotating dots animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AppLoading())),
      ),
    );

    expect(find.byType(AppLoading), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsWidgets);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppLoading), findsOneWidget);
  });

  testWidgets('accepts custom color and sizes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLoading(
              color: Colors.red,
              dotSize: 10,
              radius: 12,
            ),
          ),
        ),
      ),
    );

    final loading = tester.widget<AppLoading>(find.byType(AppLoading));
    expect(loading.color, Colors.red);
    expect(loading.dotSize, 10);
    expect(loading.radius, 12);
  });
}
