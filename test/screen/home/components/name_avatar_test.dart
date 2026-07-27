import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/screen/home/components/name_avatar.dart';

void main() {
  testWidgets('shows two-letter initials for single word', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NameAvatar(name: 'Alice')),
      ),
    );

    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('shows first and last initials for multi-word names',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NameAvatar(name: 'Jane Smith')),
      ),
    );

    expect(find.text('JS'), findsOneWidget);
  });

  testWidgets('shows question mark for empty name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NameAvatar(name: '   ')),
      ),
    );

    expect(find.text('?'), findsOneWidget);
  });

  test('colorForName is stable for the same input', () {
    expect(NameAvatar.colorForName('Speaker 1'), NameAvatar.colorForName('Speaker 1'));
  });
}
