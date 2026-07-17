/// One speech segment produced during a captioning session.
class ConversationSegment {
  ConversationSegment({
    required this.id,
    this.wavPath = '',
    required this.recordedAt,
    this.asrText = '',
  });

  final int id;
  final String wavPath;
  final DateTime recordedAt;
  String asrText;

  String get displayText => asrText.trim();

  bool get hasText => asrText.trim().isNotEmpty;
}

/// Result returned when a captioning session ends.
class LiveTranscriptResult {
  const LiveTranscriptResult({
    required this.text,
    this.segments = const [],
    this.usedAsr = false,
  });

  final String text;
  final List<ConversationSegment> segments;
  final bool usedAsr;
}
