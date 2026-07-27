import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/highlighted_text.dart';

void main() {
  testWidgets('renders full text when keyword empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HighlightedText(
            text: 'Hello world',
            keyword: '',
          ),
        ),
      ),
    );

    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('highlights matching keyword case-insensitively', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HighlightedText(
            text: 'Hello ClearHear world',
            keyword: 'clearhear',
          ),
        ),
      ),
    );

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final highlighted = richTexts.any((rich) {
      final span = rich.text;
      if (span is! TextSpan || span.children == null) return false;
      return span.children!.whereType<TextSpan>().any(
            (child) =>
                child.text == 'ClearHear' && child.style?.color == Colors.white,
          );
    });
    expect(highlighted, isTrue);
  });
}
