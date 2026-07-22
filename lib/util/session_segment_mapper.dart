import '../model/conversation_segment.dart';
import '../shared/models/segment_model.dart';

/// Maps in-memory [ConversationSegment]s to persisted [SegmentModel]s.
List<SegmentModel> mapConversationSegmentsToModels({
  required List<ConversationSegment> segments,
  required int sessionId,
  required DateTime sessionStartedAt,
  required int durationSec,
  required int createdAtEpoch,
}) {
  final withText = segments
      .where((segment) => segment.displayText.isNotEmpty)
      .toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  if (withText.isEmpty) return [];

  final sessionStartMs = sessionStartedAt.millisecondsSinceEpoch;
  final durationMs = durationSec * 1000;

  return List.generate(withText.length, (index) {
    final segment = withText[index];
    final startMs = (segment.recordedAt.millisecondsSinceEpoch - sessionStartMs)
        .clamp(0, durationMs);

    final int endMs;
    if (index + 1 < withText.length) {
      endMs = (withText[index + 1].recordedAt.millisecondsSinceEpoch -
              sessionStartMs)
          .clamp(startMs, durationMs);
    } else {
      endMs = durationMs;
    }

    return SegmentModel(
      sessionId: sessionId,
      startMs: startMs,
      endMs: endMs,
      text: segment.displayText,
      createdAt: createdAtEpoch,
      speakerLabel: segment.speakerLabel,
    );
  });
}
