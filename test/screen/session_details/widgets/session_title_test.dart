import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/session_title.dart';

void main() {
  testWidgets('shows title, date, and duration', (tester) async {
    String? saved;
    var editing = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionTitle(
            title: 'Weekly sync',
            date: 'Today',
            duration: '12 min',
            onTitleSave: (title) async => saved = title,
            onTitleEditingChanged: (value) => editing = value,
          ),
        ),
      ),
    );

    expect(find.text('Weekly sync'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.byIcon(Icons.people_alt), findsOneWidget);

    await tester.tap(find.text('Weekly sync'));
    await tester.pumpAndSettle();
    expect(editing, isTrue);

    await tester.enterText(find.byType(TextField), 'Renamed sync');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(saved, 'Renamed sync');
  });
}
