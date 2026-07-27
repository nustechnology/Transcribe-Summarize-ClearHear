import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';

/// Fake [PathProviderPlatform] that points documents/temp at a temp directory.
class TestPathProvider extends PathProviderPlatform {
  TestPathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}

/// Boots sqflite FFI + a temp-backed [DatabaseService] for repository tests.
///
/// Defaults to [SegmentSearchFtsMode.fts5] because `sqflite_common_ffi` ships
/// FTS5 only ([sqliteSupportsFts4] is false under CI). Production still
/// defaults to FTS4 — pass [ftsMode] to exercise that path when the host
/// SQLite build includes the FTS3/4 module.
///
/// Always restores the previous [PathProviderPlatform.instance] in [dispose]
/// (and on [create] failure) so tests do not leak global platform state.
class TestDatabaseHarness {
  TestDatabaseHarness._({
    required this.tempDir,
    required this.databaseService,
    required PathProviderPlatform previousPathProvider,
  }) : _previousPathProvider = previousPathProvider;

  final Directory tempDir;
  final DatabaseService databaseService;
  final PathProviderPlatform _previousPathProvider;

  static bool _ffiInitialized = false;

  /// Initializes sqflite FFI once. Safe to call repeatedly.
  static void ensureFfiInitialized() {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  /// Whether the current sqflite factory can create FTS4 virtual tables.
  ///
  /// Under `sqflite_common_ffi` this is typically false (ENABLE_FTS5 only).
  /// Mobile system SQLite used in production has FTS4.
  static Future<bool> sqliteSupportsFts4() async {
    ensureFfiInitialized();
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    try {
      final opts = await db.rawQuery('PRAGMA compile_options');
      return opts.any((row) {
        final value = row.values.first.toString().toUpperCase();
        // FTS4 is built into the FTS3 module (ENABLE_FTS3 / ENABLE_FTS3_PARENTHESIS).
        return value.contains('ENABLE_FTS3') || value.contains('ENABLE_FTS4');
      });
    } finally {
      await db.close();
    }
  }

  static Future<TestDatabaseHarness> create({
    SegmentSearchFtsMode ftsMode = SegmentSearchFtsMode.fts5,
  }) async {
    ensureFfiInitialized();

    final tempDir =
        await Directory.systemTemp.createTemp('clearhear_db_test_');
    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPathProvider(tempDir.path);

    try {
      final databaseService = DatabaseService(ftsMode: ftsMode);
      await databaseService.database;
      return TestDatabaseHarness._(
        tempDir: tempDir,
        databaseService: databaseService,
        previousPathProvider: previousPathProvider,
      );
    } catch (_) {
      PathProviderPlatform.instance = previousPathProvider;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      await databaseService.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } finally {
      PathProviderPlatform.instance = _previousPathProvider;
    }
  }
}
