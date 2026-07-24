import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/util/datetime/datetime_utils.dart';

void main() {
  group('DateTimeUtils.formatTime', () {
    test('formats midnight as 12:00 AM', () {
      expect(
        DateTimeUtils.formatTime(DateTime(2026, 1, 1, 0, 0)),
        '12:00 AM',
      );
    });

    test('formats noon as 12:00 PM', () {
      expect(
        DateTimeUtils.formatTime(DateTime(2026, 1, 1, 12, 0)),
        '12:00 PM',
      );
    });

    test('pads single-digit minutes', () {
      expect(
        DateTimeUtils.formatTime(DateTime(2026, 1, 1, 9, 5)),
        '9:05 AM',
      );
    });
  });

  group('DateTimeUtils.formatDurationFromSeconds', () {
    test('returns dash for null', () {
      expect(DateTimeUtils.formatDurationFromSeconds(null), '-');
    });

    test('formats under one hour as mm:ss', () {
      expect(DateTimeUtils.formatDurationFromSeconds(65), '01:05');
      expect(DateTimeUtils.formatDurationFromSeconds(0), '00:00');
    });

    test('formats one hour or more as hh:mm:ss', () {
      expect(DateTimeUtils.formatDurationFromSeconds(3661), '01:01:01');
    });
  });
}
