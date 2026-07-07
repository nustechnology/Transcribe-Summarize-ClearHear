/// Domain model for a finalized transcript chunk (one Whisper result).
///
/// Partial (in-progress) transcripts are NEVER written to SQLite —
/// they live only in memory inside [LiveTranscriptService].
class SegmentModel {
  const SegmentModel({
    this.id,
    required this.sessionId,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.isFinal = true,
    this.confidence,
    this.speakerLabel,
    required this.createdAt,
  });

  final int? id;
  final int sessionId;

  /// Offset from session start, milliseconds.
  final int startMs;

  /// Offset from session start, milliseconds.
  final int endMs;

  final String text;

  /// Always true for rows stored in SQLite.
  final bool isFinal;

  /// ASR confidence score in [0.0, 1.0]; null when not reported.
  final double? confidence;

  /// Speaker label; null until diarization is available.
  final String? speakerLabel;

  /// Unix epoch (seconds).
  final int createdAt;

  SegmentModel copyWith({
    int? id,
    int? sessionId,
    int? startMs,
    int? endMs,
    String? text,
    bool? isFinal,
    double? confidence,
    String? speakerLabel,
    int? createdAt,
  }) {
    return SegmentModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      text: text ?? this.text,
      isFinal: isFinal ?? this.isFinal,
      confidence: confidence ?? this.confidence,
      speakerLabel: speakerLabel ?? this.speakerLabel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'start_ms': startMs,
      'end_ms': endMs,
      'text': text,
      'is_final': isFinal ? 1 : 0,
      'confidence': confidence,
      'speaker_label': speakerLabel,
      'created_at': createdAt,
    };
  }

  factory SegmentModel.fromMap(Map<String, dynamic> map) {
    return SegmentModel(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      startMs: map['start_ms'] as int,
      endMs: map['end_ms'] as int,
      text: map['text'] as String,
      isFinal: (map['is_final'] as int? ?? 1) == 1,
      confidence: map['confidence'] as double?,
      speakerLabel: map['speaker_label'] as String?,
      createdAt: map['created_at'] as int,
    );
  }

  @override
  String toString() =>
      'SegmentModel(id: $id, sessionId: $sessionId, start: $startMs ms)';
}
