/// One speech segment saved as a WAV file during a captioning session.
class ConversationSegment {
  ConversationSegment({
    required this.id,
    required this.wavPath,
    required this.recordedAt,
    this.liveText = '',
    this.whisperText = '',
  });

  final int id;
  final String wavPath;
  final DateTime recordedAt;
  final String liveText;
  String whisperText;

  String get displayText =>
      whisperText.trim().isNotEmpty ? whisperText.trim() : liveText.trim();
}

/// Result returned when a captioning session ends.
class LiveTranscriptResult {
  const LiveTranscriptResult({
    required this.text,
    this.segments = const [],
    this.usedWhisper = false,
  });

  final String text;
  final List<ConversationSegment> segments;
  final bool usedWhisper;
}
