import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/util/mock_history_data.dart';

void main() {
  group('MockHistoryData.buildTranscriptSegments', () {
    test('produces approximately the requested word count', () {
      final segments = MockHistoryData.buildTranscriptSegments(wordCount: 120);
      final words = segments
          .expand((segment) => segment.split(RegExp(r'\s+')))
          .where((word) => word.isNotEmpty)
          .length;

      expect(words, 120);
      expect(segments, isNotEmpty);
    });

    test('flushes a trailing buffer as the last segment', () {
      final segments = MockHistoryData.buildTranscriptSegments(wordCount: 10);
      expect(segments.last.split(RegExp(r'\s+')).length, lessThanOrEqualTo(10));
      expect(
        segments.expand((s) => s.split(RegExp(r'\s+'))).length,
        10,
      );
    });

    test('transcriptSegments uses the configured word count', () {
      final words = MockHistoryData.transcriptSegments
          .expand((segment) => segment.split(RegExp(r'\s+')))
          .where((word) => word.isNotEmpty)
          .length;

      expect(words, MockHistoryData.transcriptWordCount);
    });
  });
}
