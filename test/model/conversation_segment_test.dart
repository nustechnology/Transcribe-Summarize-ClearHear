import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/model/conversation_segment.dart';
import 'package:transcribe_summarize_clearhear/model/transcript_segment_entry.dart';

void main() {
  group('ConversationSegment', () {
    test('displayText trims asrText and hasText reflects content', () {
      final empty = ConversationSegment(
        id: 1,
        recordedAt: DateTime(2026),
        asrText: '   ',
      );
      final filled = ConversationSegment(
        id: 2,
        recordedAt: DateTime(2026),
        asrText: '  hello  ',
      );

      expect(empty.displayText, isEmpty);
      expect(empty.hasText, isFalse);
      expect(filled.displayText, 'hello');
      expect(filled.hasText, isTrue);
    });

    test('clearAudioSamples frees retained PCM', () {
      final segment = ConversationSegment(
        id: 1,
        recordedAt: DateTime(2026),
        audioSamples: Float32List.fromList([0.1, 0.2]),
      );

      segment.clearAudioSamples();
      expect(segment.audioSamples, isNull);
    });
  });

  group('transcriptEntriesFromSegments', () {
    test('skips blank displayText and preserves speaker/time', () {
      final at = DateTime(2026, 3, 1, 10);
      final entries = transcriptEntriesFromSegments([
        ConversationSegment(id: 1, recordedAt: at, asrText: '  '),
        ConversationSegment(
          id: 2,
          recordedAt: at,
          asrText: 'Hello',
          speakerLabel: 'Speaker 1',
        ),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.text, 'Hello');
      expect(entries.single.speakerLabel, 'Speaker 1');
      expect(entries.single.recordedAt, at);
    });
  });

  group('LiveTranscriptResult', () {
    test('defaults segments empty and usedAsr false', () {
      const result = LiveTranscriptResult(text: 'hi');
      expect(result.segments, isEmpty);
      expect(result.usedAsr, isFalse);
    });
  });
}
