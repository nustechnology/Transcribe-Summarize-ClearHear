import 'dart:async';
import 'dart:collection';

import 'package:get/get.dart';

import '../service/database_service.dart';
import '../service/llama_service.dart';
import '../util/logger/app_logger.dart';

class SessionSummaryService extends GetxService {
  SessionSummaryService({
    required DatabaseService databaseService,
    required LlamaService llamaService,
  })  : _databaseService = databaseService,
        _llamaService = llamaService;

  final DatabaseService _databaseService;
  final LlamaService _llamaService;

  final RxMap<int, String> _statusBySessionId = <int, String>{}.obs;
  final RxMap<int, String?> _errorBySessionId = <int, String?>{}.obs;
  final Set<int> _inFlight = HashSet<int>();
  final Set<int> _pendingQueueRequests = HashSet<int>();
  Future<void> _jobChain = Future<void>.value();

  final StreamController<int> _updates = StreamController<int>.broadcast();

  Stream<int> get updates => _updates.stream;

  String statusFor(int sessionId) => _statusBySessionId[sessionId] ?? 'idle';

  String? errorFor(int sessionId) => _errorBySessionId[sessionId];

  bool isProcessing(int sessionId) {
    final status = statusFor(sessionId);
    return status == 'queued' || status == 'processing';
  }

  bool isFailed(int sessionId) => statusFor(sessionId).startsWith('failed');

  Future<void> queue(int sessionId, {bool force = false}) async {
    if (_inFlight.contains(sessionId) ||
        _pendingQueueRequests.contains(sessionId)) {
      return;
    }

    _pendingQueueRequests.add(sessionId);
    try {
      final session = await _loadSession(sessionId);
      if (session == null) return;

      if (!force && session['summary_status'] == 'ready') {
        _setState(sessionId, 'ready', null);
        return;
      }

      // Persisted queued/processing is only authoritative while the job is
      // in _inFlight. After a restart those rows are stale and should run again.
      if (!force &&
          (session['summary_status'] == 'queued' ||
              session['summary_status'] == 'processing') &&
          _inFlight.contains(sessionId)) {
        _setState(sessionId, session['summary_status'] as String, null);
        return;
      }

      _inFlight.add(sessionId);
      _setState(sessionId, 'queued', null);
      _jobChain = _jobChain
          .then((_) => _process(sessionId))
          .catchError((Object error, StackTrace stackTrace) {
        AppLogger.error(
          error: error,
          stackTrace: stackTrace,
          tag: 'SessionSummary',
        );
      });
      unawaited(_jobChain);
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'SessionSummary',
      );
    } finally {
      _pendingQueueRequests.remove(sessionId);
    }
  }

  Future<void> retry(int sessionId) => queue(sessionId, force: true);

  Future<void> _process(int sessionId) async {
    try {
      await _setDbState(sessionId, 'processing');
      final transcript = await _loadTranscript(sessionId);
      if (transcript.trim().isEmpty) {
        throw StateError('Transcript is empty');
      }

      final rawSummary = await _generateSummary(transcript);
      final summary = _normalizeSummary(rawSummary);
      await _setSummary(sessionId, summary);
      _setState(sessionId, 'ready', null);
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'SessionSummary',
      );

      final isResourceLimit = LlamaService.looksLikeResourceLimit(error);
      final status = isResourceLimit ? 'failed_resource' : 'failed';
      final message = isResourceLimit
          ? 'Summary generation failed due to system resource limits.'
          : 'Summary generation failed.';
      try {
        await _setFailure(sessionId, status, message);
      } catch (dbError, dbStack) {
        AppLogger.error(
          error: dbError,
          stackTrace: dbStack,
          tag: 'SessionSummary',
        );
      }
      _setState(sessionId, status, message);
    } finally {
      _inFlight.remove(sessionId);
    }
  }

  Future<String> _loadTranscript(int sessionId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'segments',
      columns: const ['text'],
      where: 'session_id = ? AND is_final = 1',
      whereArgs: [sessionId],
      orderBy: 'start_ms ASC',
    );

    return rows
        .map((row) => row['text'] as String? ?? '')
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
  }

  Future<String> _generateSummary(String transcript) async {
    try {
      if (!_llamaService.isModelLoaded) {
        final loaded = await _llamaService.loadBundledModel(onProgress: (_) {});
        if (!loaded) {
          throw LlamaServiceException(
            'Failed to load bundled summary model',
          );
        }
      }
      return await _llamaService.summarize(transcript);
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'SessionSummary',
      );
      rethrow;
    }
  }

  Future<void> _setSummary(int sessionId, String summary) async {
    final db = await _databaseService.database;
    await db.update(
      'sessions',
      {
        'summary': summary,
        'summary_status': 'ready',
        'summary_error': null,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<Map<String, Object?>?> _loadSession(int sessionId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'sessions',
      columns: const ['summary', 'summary_status'],
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> _setDbState(int sessionId, String status) async {
    final db = await _databaseService.database;
    await db.update(
      'sessions',
      {
        'summary_status': status,
        'summary_error': null,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    _setState(sessionId, status, null);
  }

  Future<void> _setFailure(
    int sessionId,
    String status,
    String message,
  ) async {
    final db = await _databaseService.database;
    await db.update(
      'sessions',
      {
        'summary_status': status,
        'summary_error': message,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  void _setState(int sessionId, String status, String? error) {
    _statusBySessionId[sessionId] = status;
    _errorBySessionId[sessionId] = error;
    _updates.add(sessionId);
  }

  String _normalizeSummary(String text) {
    final paragraphs = text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n{2,}'))
        .map((paragraph) => paragraph
            .split('\n')
            .map(_stripMarkdownDecorations)
            .where((line) => line.trim().isNotEmpty)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();

    final normalized = paragraphs.join('\n\n');
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= 250) return normalized;
    return words.take(250).join(' ');
  }

  String _stripMarkdownDecorations(String input) {
    return input
        .replaceAll(RegExp(r'^\s*#{1,6}\s*'), '')
        .replaceAll(RegExp(r'^\s*[-*•]\s*'), '')
        .replaceAll(RegExp(r'^\s*\d+[.)]\s*'), '')
        .replaceAll(RegExp(r'[*_`]+'), '')
        .trim();
  }

  @override
  void onClose() {
    _updates.close();
    super.onClose();
  }
}
