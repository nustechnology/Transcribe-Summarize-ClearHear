import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/util/asr_text_util.dart';

void main() {
  group('joinSegmentTexts', () {
    test('joins non-empty trimmed texts with blank-line separator', () {
      expect(
        joinSegmentTexts(['  hello  ', '', 'world', '  ']),
        'hello$segmentTextSeparator' 'world',
      );
    });

    test('returns empty string when all texts are blank', () {
      expect(joinSegmentTexts(['', '  ', '\n']), isEmpty);
    });
  });

  group('splitSegmentTexts', () {
    test('splits a joined transcript back into segments', () {
      final joined = joinSegmentTexts(['Hello', 'World today']);
      expect(splitSegmentTexts(joined), ['Hello', 'World today']);
    });

    test('returns empty list for blank transcript', () {
      expect(splitSegmentTexts('   '), isEmpty);
    });
  });

  group('formatAsrText', () {
    test('sentence-cases ALL CAPS ASR output', () {
      expect(
        formatAsrText('HELLO WORLD. HOW ARE YOU?'),
        'Hello world. How are you?',
      );
    });

    test('returns empty for blank input', () {
      expect(formatAsrText('   '), isEmpty);
    });

    test('capitalizes after sentence-ending punctuation', () {
      expect(
        formatAsrText('wait! really? yes.'),
        'Wait! Really? Yes.',
      );
    });
  });

  group('formatSegmentClockTime', () {
    test('formats midnight as 12-hour clock with seconds', () {
      expect(
        formatSegmentClockTime(DateTime(2026, 1, 1, 0, 5, 9)),
        '12:05:09 AM',
      );
    });

    test('formats afternoon times with PM', () {
      expect(
        formatSegmentClockTime(DateTime(2026, 1, 1, 15, 30, 0)),
        '03:30:00 PM',
      );
    });
  });
}
