/// Domain model for a recording session.
class SessionModel {
  const SessionModel({
    this.id,
    required this.title,
    required this.startedAt,
    this.endedAt,
    this.durationSec,
    this.isSaved = true,
    this.summary,
    this.language = 'auto',
    required this.createdAt,
  });

  final int? id;
  final String title;

  /// Unix epoch (seconds).
  final int startedAt;

  /// Null while recording is active.
  final int? endedAt;

  /// Null until session is finished.
  final int? durationSec;

  final bool isSaved;

  /// Null until AI summary is generated.
  final String? summary;

  final String language;

  /// Unix epoch (seconds).
  final int createdAt;

  SessionModel copyWith({
    int? id,
    String? title,
    int? startedAt,
    int? endedAt,
    int? durationSec,
    bool? isSaved,
    String? summary,
    String? language,
    int? createdAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSec: durationSec ?? this.durationSec,
      isSaved: isSaved ?? this.isSaved,
      summary: summary ?? this.summary,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'started_at': startedAt,
      'ended_at': endedAt,
      'duration_sec': durationSec,
      'is_saved': isSaved ? 1 : 0,
      'summary': summary,
      'language': language,
      'created_at': createdAt,
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Untitled',
      startedAt: map['started_at'] as int,
      endedAt: map['ended_at'] as int?,
      durationSec: map['duration_sec'] as int?,
      isSaved: (map['is_saved'] as int? ?? 1) == 1,
      summary: map['summary'] as String?,
      language: map['language'] as String? ?? 'auto',
      createdAt: map['created_at'] as int,
    );
  }

  @override
  String toString() =>
      'SessionModel(id: $id, title: $title, startedAt: $startedAt)';
}
