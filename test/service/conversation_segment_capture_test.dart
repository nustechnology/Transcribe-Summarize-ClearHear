import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/service/conversation_segment_capture.dart';

void main() {
  group('ConversationSegmentCapture', () {
    test('commitSegment assigns incremental ids and stores text', () {
      final capture = ConversationSegmentCapture()..start();

      final first = capture.commitSegment(text: 'one', startMs: 0, endMs: 500);
      final second =
          capture.commitSegment(text: 'two', startMs: 500, endMs: 1000);

      expect(first.id, 1);
      expect(second.id, 2);
      expect(capture.segments.map((s) => s.asrText), ['one', 'two']);
      expect(first.startMs, 0);
      expect(second.endMs, 1000);
    });

    test('start clears previous segments and resets ids', () {
      final capture = ConversationSegmentCapture()..start();
      capture.commitSegment(text: 'old');

      capture.start();
      final next = capture.commitSegment(text: 'new');

      expect(capture.segments, hasLength(1));
      expect(next.id, 1);
      expect(next.asrText, 'new');
    });

    test('dispose clears segments', () {
      final capture = ConversationSegmentCapture()..start();
      capture.commitSegment(text: 'keep');
      capture.dispose();

      expect(capture.segments, isEmpty);
    });

    test('segments getter returns an unmodifiable view', () {
      final capture = ConversationSegmentCapture()..start();
      capture.commitSegment(text: 'one');

      expect(
        () => capture.segments.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
