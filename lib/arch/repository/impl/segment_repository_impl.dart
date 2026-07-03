import 'package:flutter/foundation.dart';

import '../../../service/database_service.dart';
import '../../../shared/models/segment_model.dart';
import '../segment_repository.dart';

/// SQLite implementation of [SegmentRepository].
///
/// Key performance decisions:
/// - [insertSegments] uses sqflite batch → single COMMIT for 900+ rows.
/// - [getSegments] uses the composite index (session_id, start_ms).
/// - FTS5 is updated automatically by triggers; no manual FTS calls here.
class SegmentRepositoryImpl implements SegmentRepository {
  SegmentRepositoryImpl(this._db);

  final DatabaseService _db;

  // ── CREATE ─────────────────────────────────────────────────────────────────

  @override
  Future<int> insertSegment(SegmentModel segment) async {
    final db = await _db.database;
    final id = await db.insert('segments', segment.toMap());
    // trg_segments_ai fires → FTS5 updated automatically.
    debugPrint('[SegmentRepo] Inserted segment id=$id '
        'session=${segment.sessionId} start=${segment.startMs}ms');
    return id;
  }

  @override
  Future<void> insertSegments(List<SegmentModel> segments) async {
    if (segments.isEmpty) return;
    final db = await _db.database;

    // Single batch → one COMMIT → amortizes fsync cost for all rows.
    // noResult: true skips rowid collection → ~20% faster.
    final batch = db.batch();
    for (final seg in segments) {
      batch.insert('segments', seg.toMap());
    }
    await batch.commit(noResult: true);
    debugPrint(
      '[SegmentRepo] Batch-inserted ${segments.length} segments '
      'for session=${segments.first.sessionId}',
    );
  }

  // ── READ ───────────────────────────────────────────────────────────────────

  @override
  Future<List<SegmentModel>> getSegments(int sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'segments',
      where: 'session_id = ? AND is_final = 1',
      whereArgs: [sessionId],
      orderBy: 'start_ms ASC',
    );
    return rows.map(SegmentModel.fromMap).toList();
  }

  @override
  Future<List<SegmentModel>> getSegmentsPaged({
    required int sessionId,
    required int offset,
    required int limit,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'segments',
      where: 'session_id = ? AND is_final = 1',
      whereArgs: [sessionId],
      orderBy: 'start_ms ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(SegmentModel.fromMap).toList();
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────

  @override
  Future<void> deleteSegments(int sessionId) async {
    final db = await _db.database;
    final count = await db.delete(
      'segments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    // trg_segments_ad fires per row → FTS5 cleaned automatically.
    debugPrint(
      '[SegmentRepo] Deleted $count segments for session=$sessionId',
    );
  }
}
