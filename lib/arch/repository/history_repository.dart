import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_page_result.dart';
import 'package:transcribe_summarize_clearhear/utils/logger/app_logger.dart';

const _snippet =
    "Lorem Ipsum is simply dummy text of the printing and typesetting industry. "
    "Lorem Ipsum has been the industry's standard dummy text ever since 1966.";

List<HistoryItem> _seedHistory() {
  const titles = [
    'Team standup',
    'Dr. Okafor — appointment',
    'Lecture — Linguistics 201',
    'Client sync',
    'Therapy session notes',
    'Product roadmap review',
  ];
  const categories = ['meeting', 'health', 'lecture'];

  return List.generate(45, (index) {
    return HistoryItem(
      id: 'item-${index + 1}',
      title: titles[index % titles.length],
      timestamp: DateTime.now().subtract(Duration(hours: index * 6)),
      snippet: _snippet,
      duration: 60 + (index * 30),
      speakerCount: 1 + (index % 4),
      category: categories[index % categories.length],
    );
  });
}

class HistoryRepository {
  HistoryRepository();

  final List<HistoryItem> _allItems = _seedHistory();

  /// Offset/limit pagination — maps directly to SQLite LIMIT/OFFSET later.
  Future<HistoryPageResult> fetchSessions({
    required int offset,
    required int limit,
  }) async {
    try {
      if (offset >= _allItems.length) {
        return const HistoryPageResult(items: [], hasMore: false);
      }

      final end = offset + limit;
      final items = _allItems.sublist(
        offset,
        end > _allItems.length ? _allItems.length : end,
      );

      return HistoryPageResult(
        items: items,
        hasMore: end < _allItems.length,
      );
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return const HistoryPageResult(items: [], hasMore: false);
    }
  }

  Future<bool> updateSessionTitle(String id, String newTitle) async {
    try {
      final index = _allItems.indexWhere((item) => item.id == id);
      if (index == -1) return false;

      _allItems[index] = _allItems[index].copyWith(title: newTitle);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Bulk delete by id — maps to `DELETE FROM history WHERE id IN (...)` later.
  Future<int> deleteSessions(List<String> ids) async {
    try {
      if (ids.isEmpty) {
        return 0;
      }

      final idSet = ids.toSet();
      final beforeCount = _allItems.length;
      _allItems.removeWhere((item) => idSet.contains(item.id));
      return beforeCount - _allItems.length;
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return 0;
    }
  }
}
