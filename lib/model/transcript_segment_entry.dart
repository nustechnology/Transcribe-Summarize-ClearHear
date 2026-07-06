import 'conversation_segment.dart';

/// One transcript block shown in the UI with its wall-clock timestamp.
class TranscriptSegmentEntry {
  const TranscriptSegmentEntry({
    required this.text,
    required this.recordedAt,
  });

  final String text;
  final DateTime recordedAt;
}

List<TranscriptSegmentEntry> transcriptEntriesFromSegments(
  Iterable<ConversationSegment> segments,
) {
  return segments
      .where((segment) => segment.displayText.isNotEmpty)
      .map(
        (segment) => TranscriptSegmentEntry(
          text: segment.displayText,
          recordedAt: segment.recordedAt,
        ),
      )
      .toList(growable: false);
}
