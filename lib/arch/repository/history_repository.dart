import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_page_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';

import 'session_repository.dart';

/// Adapter that bridges the existing [HistoryController] (which uses
/// [HistoryItem] + [HistoryPageResult]) to the new [SessionRepository].
///
/// This preserves all current controller / UI contracts while
/// delegating all persistence to the real SQLite implementation.
///
/// Migration path: once [HistoryController] is refactored to consume
/// [SessionModel] directly, this adapter can be removed.
class HistoryRepository {
  HistoryRepository({required SessionRepository sessionRepository})
      : _sessionRepository = sessionRepository;

  final SessionRepository _sessionRepository;

  /// Delegates to [SessionRepository.getAllSessions] and maps results to
  /// [HistoryItem] so the existing controller needs no changes.
  Future<HistoryPageResult> fetchSessions({
    required int offset,
    required int limit,
  }) async {
    try {
      final result = await _sessionRepository.getAllSessions(
        offset: offset,
        limit: limit,
      );
      final items = result.items.map(_toHistoryItem).toList();
      return HistoryPageResult(items: items, hasMore: result.hasMore);
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return const HistoryPageResult(items: [], hasMore: false);
    }
  }

  Future<HistoryItem?> getSession(String id) async {
    try {
      final intId = int.tryParse(id);
      if (intId == null) return null;
      final session = await _sessionRepository.getSession(intId);
      if (session == null) return null;
      return _toHistoryItem(session);
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> updateSessionTitle(String id, String newTitle) async {
    try {
      final intId = int.tryParse(id);
      if (intId == null) return false;
      await _sessionRepository.updateTitle(id: intId, title: newTitle);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Bulk delete; [ids] are String to match existing controller contract.
  Future<int> deleteSessions(List<String> ids) async {
    try {
      if (ids.isEmpty) return 0;
      final intIds = ids.map(int.parse).toList();
      return _sessionRepository.deleteSessions(intIds);
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return 0;
    }
  }

  Future<List<HistorySearchHit>> searchSessions(String query) async {
    try {
      final results = await _sessionRepository.searchSessions(query);
      return results.map((result) {
        return HistorySearchHit(
          item: _toHistoryItem(result.session),
          titleMatched: result.titleMatched,
          summaryMatched: result.summaryMatched,
          transcriptMatched: result.transcriptMatched,
        );
      }).toList();
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return [];
    }
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  static HistoryItem _toHistoryItem(SessionModel session) {
    final status = session.summaryStatus;
    final snippet = _previewForSession(session);

    return HistoryItem(
      id: '${session.id}',
      title: session.title,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        session.startedAt * 1000,
      ),
      snippet: snippet,
      summaryStatus: status,
      duration: session.durationSec ?? 0,
      speakerCount: 1,
      category: 'session',
    );
  }

  static String _previewForSession(SessionModel session) {
    if (session.hasSummary) {
      return _summaryPreview(session.summary!.trim());
    }
    if (session.isSummaryProcessing) {
      return '[Generating summary...]';
    }
    if (session.endedAt != null &&
        (session.summary?.trim().isEmpty ?? true) &&
        session.summaryStatus == 'idle') {
      return '[Generating summary...]';
    }
    if (session.hasSummaryFailed) {
      if (session.summaryStatus == 'failed_resource') {
        return 'Summary generation failed due to system resource limits.';
      }
      return 'Summary generation failed.';
    }
    return session.summary?.trim() ?? '';
  }

  static String _summaryPreview(String summary) {
    final lines = summary
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first;
    return lines.take(2).join('\n');
  }
}
