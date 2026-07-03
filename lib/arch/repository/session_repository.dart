import '../../shared/models/search_result.dart';
import '../../shared/models/session_model.dart';
import '../../shared/models/session_page_result.dart';

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

  /// Writes the AI-generated summary for [id].
  Future<void> updateSummary({required int id, required String summary});

  /// Updates the display title for [id].
  Future<void> updateTitle({required int id, required String title});

  /// FTS5 full-text search across all segment text.
  ///
  /// Returns matched sessions with highlighted snippets ordered by BM25 rank.
  Future<List<SearchResult>> searchSessions(String query, {int limit = 50});
}
