import 'session_model.dart';

/// A single FTS5 search hit, representing a session that matched
/// by title, summary, or transcript text.
class SearchResult {
  const SearchResult({
    required this.session,
    required this.titleMatched,
    required this.summaryMatched,
    required this.transcriptMatched,
  });

  final SessionModel session;
  final bool titleMatched;
  final bool summaryMatched;
  final bool transcriptMatched;

  factory SearchResult.fromMap(Map<String, dynamic> map, SessionModel session) {
    return SearchResult(
      session: session,
      titleMatched: (map['title_matched'] as int?) == 1,
      summaryMatched: (map['summary_matched'] as int?) == 1,
      transcriptMatched: (map['transcript_matched'] as int?) == 1,
    );
  }

  @override
  String toString() =>
      'SearchResult(sessionId: ${session.id}, title: $titleMatched, summary: $summaryMatched, transcript: $transcriptMatched)';
}
