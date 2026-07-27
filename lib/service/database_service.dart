import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Which SQLite FTS backend to use for [segment_search].
///
/// Production always uses [fts4] (mobile system SQLite). [fts5] exists only so
/// unit tests can boot against `sqflite_common_ffi`, which ships FTS5.
/// When the host has no FTS3/4 module, production FTS4 behavior is skipped in
/// unit tests and must be validated on device / system SQLite separately.
@visibleForTesting
enum SegmentSearchFtsMode { fts4, fts5 }

/// Low-level SQLite wrapper.
///
/// Responsibilities:
/// - Open / create the database.
/// - Apply PRAGMAs (WAL, foreign keys, cache size).
/// - Expose a single [Database] instance (lazy singleton).
///
/// No business logic lives here. All repositories inject this service.
class DatabaseService {
  DatabaseService({
    @visibleForTesting this.ftsMode = SegmentSearchFtsMode.fts4,
  });

  static const _dbName = 'clearhear.db';

  // Initial schema version.
  // Increase this only when adding real migrations.
  static const _dbVersion = 3;

  /// FTS backend used when creating [segment_search]. Defaults to FTS4.
  @visibleForTesting
  final SegmentSearchFtsMode ftsMode;

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

  // ── PRAGMAs ───────────────────────────────────────────────

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

  // ── Schema creation ───────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // Tables/indexes first; FTS + triggers depend on [ftsMode].
    final batch = db.batch();
    _createTables(batch);
    _createIndexes(batch);
    await batch.commit(noResult: true);

    await _createFts(db);
    await _createTriggers(db);

    final seedBatch = db.batch();
    _seedData(seedBatch);
    await seedBatch.commit(noResult: true);
    debugPrint('[DB] Created schema v$version');
  }

  // ── Migration ──────────────────────────────────────────────

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint(
      '[DB] Upgrade $oldVersion → $newVersion',
    );

    if (oldVersion < 2) {
      await db.execute('''
        UPDATE settings
        SET font_size = MIN(MAX(font_size, 12.0), 20.0)
        WHERE id = 1
      ''');
    }

    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        'sessions',
        'summary_status',
        "TEXT NOT NULL DEFAULT 'idle'",
      );
      await _addColumnIfMissing(
        db,
        'sessions',
        'summary_error',
        'TEXT',
      );
      await db.execute('''
        UPDATE sessions
        SET summary_status = 'ready'
        WHERE summary IS NOT NULL AND TRIM(summary) != ''
      ''');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  void _createTables(Batch batch) {
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
        summary_status TEXT NOT NULL DEFAULT 'idle',
        summary_error TEXT,
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
        font_size       REAL    NOT NULL DEFAULT 16.0
                                CHECK (font_size >= 12.0 AND font_size <= 20.0),
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

  void _createIndexes(Batch batch) {
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

  Future<void> _createTriggers(Database db) async {
    // Prefer rowid so triggers work for both FTS4 (docid alias) and FTS5.
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_segments_ai
        AFTER INSERT ON segments
      BEGIN
        INSERT INTO segment_search (rowid, text, session_id)
        VALUES (NEW.id, NEW.text, NEW.session_id);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_segments_ad
        AFTER DELETE ON segments
      BEGIN
        DELETE FROM segment_search WHERE rowid = OLD.id;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_segments_au
        AFTER UPDATE OF text ON segments
      BEGIN
        DELETE FROM segment_search WHERE rowid = OLD.id;
        INSERT INTO segment_search (rowid, text, session_id)
        VALUES (NEW.id, NEW.text, NEW.session_id);
      END
    ''');
  }

  /// Creates the FTS mirror of [segments.text].
  ///
  /// Production uses FTS4 (external-content). Tests may inject FTS5 for FFI.
  Future<void> _createFts(Database db) async {
    switch (ftsMode) {
      case SegmentSearchFtsMode.fts4:
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS segment_search
          USING fts4 (
            content="segments",
            text,
            session_id,
            notindexed=session_id,
            tokenize=unicode61
          )
        ''');
      case SegmentSearchFtsMode.fts5:
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS segment_search
          USING fts5 (
            text,
            session_id UNINDEXED,
            tokenize='unicode61'
          )
        ''');
    }
  }

  void _seedData(Batch batch) {
    // Settings singleton: INSERT OR IGNORE so re-runs are idempotent.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    batch.execute('''
      INSERT OR IGNORE INTO settings
        (id, font_size, theme, saving_enabled, keep_screen_on, power_saver, updated_at)
      VALUES (1, 16.0, 'system', 1, 0, 0, $now)
    ''');
  }

  // ── Lifecycle ──────────────────────────────────────────────

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
