import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';

import '../helpers/test_database.dart';

void main() {
  test('defaults to FTS4 for production schema', () {
    expect(DatabaseService().ftsMode, SegmentSearchFtsMode.fts4);
  });

  group('with FTS5 test harness', () {
    TestDatabaseHarness? harness;

    setUp(() async {
      harness = await TestDatabaseHarness.create();
    });

    tearDown(() async {
      await harness?.dispose();
    });

    test('creates sessions, segments, settings tables and seeds settings',
        () async {
      final db = await harness!.databaseService.database;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((row) => row['name'] as String).toSet();
      expect(names, containsAll(['sessions', 'segments', 'settings']));
      expect(names, contains('segment_search'));
      expect(harness!.databaseService.ftsMode, SegmentSearchFtsMode.fts5);

      final settings = await db.query('settings', where: 'id = 1');
      expect(settings, hasLength(1));
      expect(settings.single['font_size'], 16.0);
      expect(settings.single['theme'], 'system');
    });

    test('FTS trigger mirrors segment insert, update, delete, and search',
        () async {
      final db = await harness!.databaseService.database;
      await expectFtsTriggersMirrorSegments(db);
    });

    test('foreign key cascade deletes segments with session', () async {
      final db = await harness!.databaseService.database;

      final sessionId = await db.insert('sessions', {
        'title': 'Cascade',
        'started_at': 1,
        'created_at': 1,
        'is_saved': 1,
      });
      await db.insert(
        'segments',
        SegmentModel(
          sessionId: sessionId,
          startMs: 0,
          endMs: 500,
          text: 'bye',
          createdAt: 1,
        ).toMap(),
      );

      await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);

      final remaining = await db.query(
        'segments',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      expect(remaining, isEmpty);
    });
  });

  /// Production opens FTS4 (external-content + rowid triggers). Unit CI uses
  /// `sqflite_common_ffi`, which typically has FTS5 only — when FTS4 is absent
  /// this test skips and FTS4 must be validated on device / system SQLite.
  test(
    'production FTS4 schema mirrors insert, update, delete, and search '
    'when available',
    () async {
      if (!await TestDatabaseHarness.sqliteSupportsFts4()) {
        markTestSkipped(
          'sqflite_common_ffi has FTS5 only (no FTS3/4 module). '
          'Validate production FTS4 (external-content + rowid triggers) on '
          'device or against system SQLite separately.',
        );
        return;
      }

      final harness = await TestDatabaseHarness.create(
        ftsMode: SegmentSearchFtsMode.fts4,
      );
      try {
        expect(harness.databaseService.ftsMode, SegmentSearchFtsMode.fts4);
        final db = await harness.databaseService.database;

        final ftsSql = await db.rawQuery(
          "SELECT sql FROM sqlite_master "
          "WHERE type='table' AND name='segment_search'",
        );
        expect(
          ftsSql.single['sql']?.toString().toLowerCase(),
          contains('fts4'),
        );

        await expectFtsTriggersMirrorSegments(db);
      } finally {
        await harness.dispose();
      }
    },
  );
}

/// Shared insert → MATCH → update → MATCH → delete → MATCH checks for the
/// `segment_search` triggers (works for both FTS4 and FTS5 via `rowid`).
Future<void> expectFtsTriggersMirrorSegments(Database db) async {
  final sessionId = await db.insert('sessions', {
    'title': 'FTS',
    'started_at': 1,
    'created_at': 1,
    'is_saved': 1,
  });

  final segmentId = await db.insert(
    'segments',
    SegmentModel(
      sessionId: sessionId,
      startMs: 0,
      endMs: 1000,
      text: 'hello transcript world',
      createdAt: 1,
    ).toMap(),
  );

  // Insert → search finds the segment.
  final insertHits = await db.rawQuery(
    'SELECT rowid, session_id FROM segment_search '
    'WHERE segment_search MATCH ?',
    ['"hello"'],
  );
  expect(insertHits, hasLength(1));
  expect(insertHits.single['rowid'], segmentId);
  expect(insertHits.single['session_id'], sessionId);

  // Update text → old term gone, new term matches.
  await db.update(
    'segments',
    {'text': 'goodbye transcript world'},
    where: 'id = ?',
    whereArgs: [segmentId],
  );
  final afterOldTerm = await db.rawQuery(
    'SELECT rowid FROM segment_search WHERE segment_search MATCH ?',
    ['"hello"'],
  );
  expect(afterOldTerm, isEmpty);

  final afterNewTerm = await db.rawQuery(
    'SELECT rowid FROM segment_search WHERE segment_search MATCH ?',
    ['"goodbye"'],
  );
  expect(afterNewTerm, hasLength(1));
  expect(afterNewTerm.single['rowid'], segmentId);

  // Delete → no MATCH hits.
  await db.delete('segments', where: 'id = ?', whereArgs: [segmentId]);
  final afterDelete = await db.rawQuery(
    'SELECT rowid FROM segment_search WHERE segment_search MATCH ?',
    ['"goodbye"'],
  );
  expect(afterDelete, isEmpty);
}
