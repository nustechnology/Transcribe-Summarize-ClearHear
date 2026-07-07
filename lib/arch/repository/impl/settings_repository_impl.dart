import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/settings_model.dart';

/// SQLite implementation of [SettingsRepository].
///
/// The settings table enforces exactly one row via `CHECK (id = 1)`.
/// All writes use INSERT OR REPLACE so the singleton is created on first use
/// even if the seeded row was somehow absent.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db);

  final DatabaseService _db;

  // ── READ ───────────────────────────────────────────────────────────────────

  @override
  Future<SettingsModel> loadSettings() async {
    final db = await _db.database;
    final rows = await db.query('settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      // Fallback: seed defaults if the row is somehow missing.
      final defaults = SettingsModel.defaults();
      await _upsert(db, defaults);
      return defaults;
    }
    return SettingsModel.fromMap(rows.first);
  }

  // ── WRITE ──────────────────────────────────────────────────────────────────

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    final db = await _db.database;
    await _upsert(db, settings);
    debugPrint('[SettingsRepo] Settings saved: $settings');
  }

  @override
  Future<void> updateTheme(String theme) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final db = await _db.database;
    final count = await db.update(
      'settings',
      {'theme': theme, 'updated_at': now},
      where: 'id = 1',
    );
    if (count == 0) {
      await _upsert(
          db, SettingsModel.defaults().copyWith(theme: theme, updatedAt: now));
    }
    debugPrint('[SettingsRepo] Theme updated → $theme');
  }

  @override
  Future<void> updateFontSize(double fontSize) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final db = await _db.database;
    await db.update(
      'settings',
      {'font_size': fontSize, 'updated_at': now},
      where: 'id = 1',
    );
    debugPrint('[SettingsRepo] Font size updated → $fontSize');
  }

  @override
  Future<void> updateSavingEnabled({required bool enabled}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final db = await _db.database;
    await db.update(
      'settings',
      {'saving_enabled': enabled ? 1 : 0, 'updated_at': now},
      where: 'id = 1',
    );
    debugPrint('[SettingsRepo] saving_enabled → $enabled');
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  Future<void> _upsert(Database db, SettingsModel settings) async {
    await db.insert(
      'settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
