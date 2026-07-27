import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_dialog.dart';

void main() {
  testWidgets('shows title, message, and primary action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDialog(
            title: 'Confirm',
            message: 'Are you sure?',
            primaryLabel: 'OK',
            onPrimary: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Are you sure?'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);

    await tester.tap(find.text('OK'));
    expect(tapped, isTrue);
  });

  testWidgets('shows secondary action when provided', (tester) async {
    var primary = false;
    var secondary = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDialog(
            title: 'Delete?',
            message: 'This cannot be undone.',
            primaryLabel: 'Delete',
            onPrimary: () => primary = true,
            secondaryLabel: 'Cancel',
            onSecondary: () => secondary = true,
            icon: Icons.delete_outline,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    expect(secondary, isTrue);
    expect(primary, isFalse);

    await tester.tap(find.text('Delete'));
    expect(primary, isTrue);
  });
}
