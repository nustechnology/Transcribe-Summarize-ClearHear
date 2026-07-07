import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';

class HistoryPageResult {
  const HistoryPageResult({
    required this.items,
    required this.hasMore,
  });

  final List<HistoryItem> items;
  final bool hasMore;
}
