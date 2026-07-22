import 'package:flutter/foundation.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';

/// SQLite implementation of [SessionRepository].
///
/// All writes use parameterized queries (no string interpolation).
/// Cascade deletes are handled by the FK constraint + triggers; no manual
/// segment cleanup is needed when deleting a session.
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._db);

  final DatabaseService _db;

  // ── CREATE ─────────────────────────────────────────────────────────────────

  @override
  Future<int> createSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) async {
    final db = await _db.database;
    final id = await db.insert(
      'sessions',
      {
        'title': title,
        'started_at': startedAt,
        'language': language,
        'is_saved': 1,
        'created_at': startedAt,
      },
    );
    debugPrint('[SessionRepo] Created session id=$id');
    return id;
  }

  @override
  Future<int> createDraftSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) async {
    final db = await _db.database;
    final id = await db.insert(
      'sessions',
      {
        'title': title,
        'started_at': startedAt,
        'language': language,
        'is_saved': 0,
        'created_at': startedAt,
      },
    );
    debugPrint('[SessionRepo] Created draft session id=$id');
    return id;
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────

  @override
  Future<void> finishSession({
    required int id,
    required int endedAt,
    required int durationSec,
  }) async {
    final db = await _db.database;
    await db.update(
      'sessions',
      {'ended_at': endedAt, 'duration_sec': durationSec},
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint(
        '[SessionRepo] Finished session id=$id duration=${durationSec}s');
  }

  @override
  Future<void> markSessionSaved({
    required int id,
    required String title,
    required int endedAt,
    required int durationSec,
  }) async {
    final db = await _db.database;
    await db.update(
      'sessions',
      {
        'title': title,
        'ended_at': endedAt,
        'duration_sec': durationSec,
        'is_saved': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('[SessionRepo] Marked session saved id=$id');
  }

  @override
  Future<void> updateSummary({
    required int id,
    required String summary,
  }) async {
    final db = await _db.database;
    await db.update(
      'sessions',
      {'summary': summary},
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('[SessionRepo] Summary saved for session id=$id');
  }

  @override
  Future<void> updateTitle({required int id, required String title}) async {
    final db = await _db.database;
    await db.update(
      'sessions',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── READ ───────────────────────────────────────────────────────────────────

  @override
  Future<SessionModel?> getSession(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SessionModel.fromMap(rows.first);
  }

  @override
  Future<List<SessionModel>> getUnsavedSessions() async {
    final db = await _db.database;
    final rows = await db.query(
      'sessions',
      where: 'is_saved = 0',
      orderBy: 'started_at ASC',
    );
    return rows.map(SessionModel.fromMap).toList();
  }

  @override
  Future<SessionPageResult> getAllSessions({
    required int offset,
    required int limit,
    bool savedOnly = false,
  }) async {
    try {
      final db = await _db.database;
      final where = savedOnly ? 'is_saved = 1' : null;

      final rows = await db.query(
        'sessions',
        where: where,
        orderBy: 'started_at DESC',
        limit: limit,
        offset: offset,
      );

      final items = rows.map(SessionModel.fromMap).toList();
      return SessionPageResult(
        items: items,
        hasMore: items.length == limit,
      );
    } catch (error) {
      rethrow;
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────

  @override
  Future<void> deleteSession(int id) async {
    final db = await _db.database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    // ON DELETE CASCADE removes segments; trg_segments_ad removes FTS rows.
    debugPrint('[SessionRepo] Deleted session id=$id');
  }

  @override
  Future<int> deleteSessions(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await _db.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final count = await db.rawDelete(
      'DELETE FROM sessions WHERE id IN ($placeholders)',
      ids,
    );
    debugPrint('[SessionRepo] Deleted $count sessions');
    return count;
  }

  @override
  Future<void> deleteAllSessions() async {
    final db = await _db.database;
    await db.delete('sessions');
    debugPrint('[SessionRepo] Deleted all sessions');
  }

  // ── SEARCH ─────────────────────────────────────────────────────────────────

  @override
  Future<List<SearchResult>> searchSessions(
    String query, {
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final db = await _db.database;
    final ftsQuery = _buildFtsQuery(trimmed);
    final likeQuery = '%${_escapeLike(trimmed)}%';
    final rows = await db.rawQuery('''
      WITH matched_sessions AS (
        SELECT
          id,
          (title LIKE ? ESCAPE '\\') AS title_matched,
          (summary LIKE ? ESCAPE '\\') AS summary_matched,
          0 AS transcript_matched
        FROM sessions
        WHERE title LIKE ? ESCAPE '\\' OR summary LIKE ? ESCAPE '\\'

        UNION ALL

        SELECT
          session_id AS id,
          0 AS title_matched,
          0 AS summary_matched,
          1 AS transcript_matched
        FROM segment_search
        WHERE segment_search MATCH ?
      )
      SELECT
        s.*,
        MAX(m.title_matched) AS title_matched,
        MAX(m.summary_matched) AS summary_matched,
        MAX(m.transcript_matched) AS transcript_matched
      FROM sessions s
      JOIN matched_sessions m ON s.id = m.id
      WHERE s.is_saved = 1
      GROUP BY s.id
      ORDER BY s.started_at DESC
      LIMIT ?
    ''', [likeQuery, likeQuery, likeQuery, likeQuery, ftsQuery, limit]);
    AppLogger.info('[searchSessions] ${rows.length} results');
    return rows.map((row) {
      final session = SessionModel.fromMap(row);
      return SearchResult.fromMap(row, session);
    }).toList();
  }

  /// Escapes LIKE wildcards so a query containing `%` or `_` is matched
  /// literally instead of being treated as a pattern.
  String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// Wraps each whitespace-delimited token in double quotes for FTS5 exact
  /// token matching, preventing injection via special characters.
  String _buildFtsQuery(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '')}"')
        .join(' ');
  }
}
