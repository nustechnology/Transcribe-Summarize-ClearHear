import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/transcript_message_item.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

void main() {
  test('speakerInitials for Speaker N labels', () {
    expect(speakerInitials('Speaker 1'), 'S1');
    expect(speakerInitials('Speaker 12'), 'S12');
  });

  test('speakerInitials for multi-word names', () {
    expect(speakerInitials('Jane Smith'), 'JS');
    expect(speakerInitials('Jane'), 'JA');
  });

  test('colorForSpeaker is stable and cycles palette', () {
    expect(
      AppColors.colorForSpeaker('Speaker 1'),
      AppColors.speakerPalette[0],
    );
    expect(
      AppColors.colorForSpeaker('Speaker 2'),
      AppColors.speakerPalette[1],
    );
    expect(
      AppColors.colorForSpeaker('Speaker 1'),
      AppColors.colorForSpeaker('Speaker 1'),
    );
    expect(
      AppColors.colorForSpeaker('Speaker 13'),
      AppColors.speakerPalette[0],
    );
  });

  testWidgets('renders time, message, and speaker label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TranscriptMessageItem(
            time: '00:12',
            message: 'Hello there',
            speakerLabel: 'Speaker 1',
          ),
        ),
      ),
    );

    expect(find.text('00:12'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('Speaker 1'), findsOneWidget);
    expect(find.text('S1'), findsOneWidget);
  });

  testWidgets('omits speaker row when label missing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TranscriptMessageItem(
            time: '00:01',
            message: 'No speaker',
          ),
        ),
      ),
    );

    expect(find.text('No speaker'), findsOneWidget);
    expect(find.text('Speaker 1'), findsNothing);
  });
}
