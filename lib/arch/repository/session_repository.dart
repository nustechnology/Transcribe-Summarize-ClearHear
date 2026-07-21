import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';

/// Abstract contract for all session persistence operations.
///
/// Controllers depend on this interface — never on the implementation.
/// Swap the implementation (SQLite → in-memory stub) without touching UI.
abstract class SessionRepository {
  /// Creates a new session row and returns the auto-generated [id].
  Future<int> createSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  });

  /// Creates an unsaved (is_saved = 0) draft session and returns its [id].
  Future<int> createDraftSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  });

  /// Returns every unsaved (is_saved = 0) session, ordered by [started_at] ASC.
  Future<List<SessionModel>> getUnsavedSessions();

  /// Flips a draft to saved: sets [title], [endedAt], [durationSec], is_saved.
  Future<void> markSessionSaved({
    required int id,
    required String title,
    required int endedAt,
    required int durationSec,
  });

  /// Updates [endedAt] and [durationSec] when recording stops.
  Future<void> finishSession({
    required int id,
    required int endedAt,
    required int durationSec,
  });

  /// Returns the session with [id], or null if not found.
  Future<SessionModel?> getSession(int id);

  /// Paginated history list ordered by [started_at] DESC.
  ///
  /// Pass [savedOnly] = true to show only is_saved = 1 rows.
  Future<SessionPageResult> getAllSessions({
    required int offset,
    required int limit,
    bool savedOnly = false,
  });

  /// Deletes a single session.
  ///
  /// Cascade removes all segments and FTS rows automatically.
  Future<void> deleteSession(int id);

  /// Bulk-deletes sessions by id list. Returns the number of rows deleted.
  Future<int> deleteSessions(List<int> ids);

  /// Deletes every session row (segments and FTS rows cascade).
  Future<void> deleteAllSessions();

  /// Writes the AI-generated summary for [id].
  Future<void> updateSummary({required int id, required String summary});

  /// Updates the display title for [id].
  Future<void> updateTitle({required int id, required String title});

  /// FTS5 full-text search across all segment text.
  ///
  /// Returns matched sessions with highlighted snippets ordered by BM25 rank.
  Future<List<SearchResult>> searchSessions(String query, {int limit = 50});
}
