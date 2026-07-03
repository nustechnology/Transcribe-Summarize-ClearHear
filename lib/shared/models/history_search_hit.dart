import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';

class HistorySearchHit {
  const HistorySearchHit({
    required this.item,
    required this.titleMatched,
    required this.summaryMatched,
    required this.transcriptMatched,
  });

  final HistoryItem item;
  final bool titleMatched;
  final bool summaryMatched;
  final bool transcriptMatched;
}
