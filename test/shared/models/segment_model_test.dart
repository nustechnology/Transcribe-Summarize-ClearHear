import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';

void main() {
  const segment = SegmentModel(
    id: 9,
    sessionId: 3,
    startMs: 1000,
    endMs: 2500,
    text: 'Hello there',
    isFinal: true,
    confidence: 0.91,
    speakerLabel: 'Speaker 1',
    createdAt: 1700000000,
  );

  test('toMap / fromMap round-trip', () {
    final restored = SegmentModel.fromMap(segment.toMap());

    expect(restored.id, segment.id);
    expect(restored.sessionId, segment.sessionId);
    expect(restored.startMs, segment.startMs);
    expect(restored.endMs, segment.endMs);
    expect(restored.text, segment.text);
    expect(restored.isFinal, isTrue);
    expect(restored.confidence, 0.91);
    expect(restored.speakerLabel, 'Speaker 1');
    expect(restored.createdAt, segment.createdAt);
  });

  test('fromMap defaults is_final to true when missing', () {
    final restored = SegmentModel.fromMap({
      'session_id': 1,
      'start_ms': 0,
      'end_ms': 100,
      'text': 'hi',
      'created_at': 1,
    });

    expect(restored.isFinal, isTrue);
    expect(restored.speakerLabel, isNull);
    expect(restored.confidence, isNull);
  });

  test('copyWith overrides selected fields only', () {
    final updated = segment.copyWith(
      text: 'Updated',
      speakerLabel: 'Speaker 2',
    );

    expect(updated.text, 'Updated');
    expect(updated.speakerLabel, 'Speaker 2');
    expect(updated.sessionId, segment.sessionId);
    expect(updated.startMs, segment.startMs);
  });
}
