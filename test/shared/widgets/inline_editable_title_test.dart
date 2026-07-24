import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/inline_editable_title.dart';

void main() {
  testWidgets('shows initial title and enters edit on tap', (tester) async {
    String? saved;
    var editing = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineEditableTitle(
            initialTitle: 'My Session',
            onSave: (title) async => saved = title,
            onEditingChanged: (value) => editing = value,
            showTrailingIcon: true,
          ),
        ),
      ),
    );

    expect(find.text('My Session'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);

    await tester.tap(find.text('My Session'));
    await tester.pumpAndSettle();

    expect(editing, isTrue);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(saved, 'Renamed');
    expect(editing, isFalse);
  });

  testWidgets('selection mode routes tap to selection callback', (tester) async {
    var selected = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineEditableTitle(
            initialTitle: 'Selectable',
            isSelectionMode: true,
            onSave: (_) async {},
            onTapSelectionMode: () => selected = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Selectable'));
    await tester.pump();

    expect(selected, isTrue);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('custom onTap prevents inline editing', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineEditableTitle(
            initialTitle: 'Open detail',
            onSave: (_) async {},
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open detail'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(find.byType(TextField), findsNothing);
  });
}
