import 'dart:typed_data';

/// One speech segment produced during a captioning session.
class ConversationSegment {
  ConversationSegment({
    required this.id,
    this.wavPath = '',
    required this.recordedAt,
    this.asrText = '',
    this.startMs = 0,
    this.endMs = 0,
    this.speakerLabel,
    this.audioSamples,
  });

  final int id;
  final String wavPath;
  final DateTime recordedAt;
  String asrText;

  /// Session-relative offsets (milliseconds since the recording started),
  /// used to match this segment against speaker diarization time spans.
  final int startMs;
  final int endMs;

  /// Live (and optionally re-labeled at pause/finish) speaker id for this
  /// utterance; null if labeling was skipped or failed.
  String? speakerLabel;

  /// Optional mono float32 @ 16 kHz retained until pause/finish so speakers
  /// can be re-labeled from full utterance audio. Cleared after relabel or
  /// dispose to free memory.
  Float32List? audioSamples;

  String get displayText => asrText.trim();

  bool get hasText => asrText.trim().isNotEmpty;

  void clearAudioSamples() {
    audioSamples = null;
  }
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
