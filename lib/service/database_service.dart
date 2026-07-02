import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Low-level SQLite wrapper.
///
/// Responsibilities:
/// - Open / migrate the database.
/// - Apply PRAGMAs (WAL, foreign keys, cache size).
/// - Expose a single [Database] instance (lazy singleton).
///
/// No business logic lives here. All repositories inject this service.
class DatabaseService {
  static const _dbName = 'clearhear.db';
  static const _dbVersion = 3;

  Database? _db;

  /// Returns the open database, opening it on first call.
  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _applyPragmas,
    );
  }

  // ── PRAGMAs ──────────────────────────────────────────────────────────────

  Future<void> _applyPragmas(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // rawQuery is used here because journal_mode returns a row ('wal').
    // sqflite iOS/macOS driver throws an error if db.execute receives a result set.
    await db.rawQuery('PRAGMA journal_mode = WAL');
    // NORMAL is crash-safe with WAL and significantly faster than FULL.
    await db.execute('PRAGMA synchronous = NORMAL');
    // 8 MB page cache keeps hot indexes in RAM.
    await db.execute('PRAGMA cache_size = -8000');
    await db.execute('PRAGMA temp_store = MEMORY');
  }

  // ── Schema creation ───────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // Run all DDL in a single batch for speed.
    final batch = db.batch();
    _applyV1Tables(batch);
    _applyV1Indexes(batch);
    _applyV1Triggers(batch);
    _applyV1Fts(batch);
    _applyV1Seed(batch);
    await batch.commit(noResult: true);
    debugPrint('[DB] Created schema v$version');
  }

  // ── Migration ─────────────────────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[DB] Upgrading from v$oldVersion → v$newVersion');
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      await db.transaction((txn) => _runMigration(txn, v));
    }
  }

  Future<void> _runMigration(Transaction txn, int version) async {
    switch (version) {
      case 2:
        // v2: add confidence column to segments.
        await txn.execute('''
          ALTER TABLE segments
          ADD COLUMN confidence REAL
          CHECK (confidence IS NULL OR (confidence >= 0.0 AND confidence <= 1.0))
        ''');
        debugPrint('[DB] Migration v2 applied');

      case 3:
        // v3: add language column to sessions.
        await txn.execute(
          "ALTER TABLE sessions ADD COLUMN language TEXT NOT NULL DEFAULT 'auto'",
        );
        debugPrint('[DB] Migration v3 applied');
    }
  }

  // ── DDL helpers ───────────────────────────────────────────────────────────

  void _applyV1Tables(Batch batch) {
    // sessions ---------------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        title        TEXT    NOT NULL DEFAULT 'Untitled',
        started_at   INTEGER NOT NULL,
        ended_at     INTEGER,
        duration_sec INTEGER CHECK (duration_sec IS NULL OR duration_sec >= 0),
        is_saved     INTEGER NOT NULL DEFAULT 1
                             CHECK (is_saved IN (0, 1)),
        summary      TEXT,
        language     TEXT    NOT NULL DEFAULT 'auto',
        created_at   INTEGER NOT NULL
      )
    ''');

    // segments ---------------------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS segments (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id    INTEGER NOT NULL
                              REFERENCES sessions(id) ON DELETE CASCADE,
        start_ms      INTEGER NOT NULL CHECK (start_ms >= 0),
        end_ms        INTEGER NOT NULL CHECK (end_ms >= start_ms),
        text          TEXT    NOT NULL,
        is_final      INTEGER NOT NULL DEFAULT 1
                              CHECK (is_final IN (0, 1)),
        confidence    REAL
                              CHECK (confidence IS NULL OR
                                     (confidence >= 0.0 AND confidence <= 1.0)),
        speaker_label TEXT,
        created_at    INTEGER NOT NULL
      )
    ''');

    // settings (singleton) ---------------------------------------------------
    batch.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id              INTEGER PRIMARY KEY CHECK (id = 1),
        font_size       REAL    NOT NULL DEFAULT 20.0
                                CHECK (font_size >= 12.0 AND font_size <= 48.0),
        theme           TEXT    NOT NULL DEFAULT 'system'
                                CHECK (theme IN ('light', 'dark', 'system')),
        saving_enabled  INTEGER NOT NULL DEFAULT 1
                                CHECK (saving_enabled IN (0, 1)),
        keep_screen_on  INTEGER NOT NULL DEFAULT 0
                                CHECK (keep_screen_on IN (0, 1)),
        power_saver     INTEGER NOT NULL DEFAULT 0
                                CHECK (power_saver IN (0, 1)),
        updated_at      INTEGER NOT NULL
      )
    ''');
  }

  void _applyV1Indexes(Batch batch) {
    // History screen: list sessions by most-recent start.
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_sessions_started_at
        ON sessions (started_at DESC)
    ''');

    // Filtered history (saved-only toggle).
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_sessions_is_saved
        ON sessions (is_saved, started_at DESC)
    ''');

    // Transcript viewer: load segments ordered by time.
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_segments_session_start
        ON segments (session_id, start_ms ASC)
    ''');

    // Speed up CASCADE DELETE scanning.
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_segments_session_id
        ON segments (session_id)
    ''');
  }

  void _applyV1Triggers(Batch batch) {
    // FTS5 INSERT sync
    batch.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_segments_ai
        AFTER INSERT ON segments
      BEGIN
        INSERT INTO segment_search (rowid, text, session_id)
        VALUES (NEW.id, NEW.text, NEW.session_id);
      END
    ''');

    // FTS5 DELETE sync
    batch.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_segments_ad
        AFTER DELETE ON segments
      BEGIN
        DELETE FROM segment_search WHERE rowid = OLD.id;
      END
    ''');

    // FTS5 UPDATE sync (text changed)
    batch.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_segments_au
        AFTER UPDATE OF text ON segments
      BEGIN
        DELETE FROM segment_search WHERE rowid = OLD.id;
        INSERT INTO segment_search (rowid, text, session_id)
        VALUES (NEW.id, NEW.text, NEW.session_id);
      END
    ''');
  }

  void _applyV1Fts(Batch batch) {
    // FTS5 virtual table — external content mirrors segments.
    // unicode61 with remove_diacritics handles accented/multilingual text.
    batch.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS segment_search
      USING fts5 (
        text,
        session_id UNINDEXED,
        content     = segments,
        content_rowid = id,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
  }

  void _applyV1Seed(Batch batch) {
    // Settings singleton: INSERT OR IGNORE so re-runs are idempotent.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    batch.execute('''
      INSERT OR IGNORE INTO settings
        (id, font_size, theme, saving_enabled, keep_screen_on, power_saver, updated_at)
      VALUES (1, 20.0, 'system', 1, 0, 0, $now)
    ''');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
