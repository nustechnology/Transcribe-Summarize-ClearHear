import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/model/conversation_segment.dart';
import 'package:transcribe_summarize_clearhear/util/session_segment_mapper.dart';

void main() {
  final sessionStart = DateTime(2026, 1, 1, 10, 0, 0);

  ConversationSegment segment({
    required int id,
    required DateTime recordedAt,
    required String text,
    String? speakerLabel,
  }) {
    return ConversationSegment(
      id: id,
      recordedAt: recordedAt,
      asrText: text,
      speakerLabel: speakerLabel,
    );
  }

  group('mapConversationSegmentsToModels', () {
    test('returns empty when all segments lack text', () {
      final models = mapConversationSegmentsToModels(
        segments: [
          segment(id: 1, recordedAt: sessionStart, text: '  '),
        ],
        sessionId: 7,
        sessionStartedAt: sessionStart,
        durationSec: 60,
        createdAtEpoch: 100,
      );
      expect(models, isEmpty);
    });

    test('maps offsets relative to session start and sorts by time', () {
      final later = sessionStart.add(const Duration(seconds: 10));
      final earlier = sessionStart.add(const Duration(seconds: 2));

      final models = mapConversationSegmentsToModels(
        segments: [
          segment(
            id: 2,
            recordedAt: later,
            text: 'second',
            speakerLabel: 'Speaker 2',
          ),
          segment(
            id: 1,
            recordedAt: earlier,
            text: 'first',
            speakerLabel: 'Speaker 1',
          ),
        ],
        sessionId: 7,
        sessionStartedAt: sessionStart,
        durationSec: 60,
        createdAtEpoch: 100,
      );

      expect(models, hasLength(2));
      expect(models[0].text, 'first');
      expect(models[0].startMs, 2000);
      expect(models[0].endMs, 10000);
      expect(models[0].speakerLabel, 'Speaker 1');
      expect(models[0].sessionId, 7);
      expect(models[0].createdAt, 100);

      expect(models[1].text, 'second');
      expect(models[1].startMs, 10000);
      expect(models[1].endMs, 60000);
      expect(models[1].speakerLabel, 'Speaker 2');
    });

    test('clamps start/end within session duration', () {
      final beforeStart = sessionStart.subtract(const Duration(seconds: 5));
      final afterEnd = sessionStart.add(const Duration(seconds: 90));

      final models = mapConversationSegmentsToModels(
        segments: [
          segment(id: 1, recordedAt: beforeStart, text: 'early'),
          segment(id: 2, recordedAt: afterEnd, text: 'late'),
        ],
        sessionId: 1,
        sessionStartedAt: sessionStart,
        durationSec: 60,
        createdAtEpoch: 1,
      );

      expect(models[0].startMs, 0);
      expect(models[0].endMs, 60000);
      expect(models[1].startMs, 60000);
      expect(models[1].endMs, 60000);
    });
  });
}
