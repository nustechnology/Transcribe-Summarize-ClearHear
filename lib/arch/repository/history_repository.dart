import '../../shared/models/history_item.dart';
import '../../shared/models/history_page_result.dart';
import '../../shared/models/history_search_hit.dart';
import '../../shared/models/session_model.dart';
import '../../utils/logger/app_logger.dart';
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
    return HistoryItem(
      id: '${session.id}',
      title: session.title,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        session.startedAt * 1000,
      ),
      snippet: session.summary ?? '',
      duration: session.durationSec ?? 0,
      speakerCount: 1,
      category: 'session',
    );
  }
}
