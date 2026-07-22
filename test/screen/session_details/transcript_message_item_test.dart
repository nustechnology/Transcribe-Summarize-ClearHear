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
}
