import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_page_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';

void main() {
  final item = HistoryItem(
    id: '1',
    title: 'A',
    timestamp: DateTime(2026),
    snippet: 's',
    summaryStatus: 'ready',
    duration: 10,
    speakerCount: 1,
    category: 'session',
  );

  test('HistoryPageResult holds items and hasMore', () {
    const page = HistoryPageResult(items: [], hasMore: true);
    expect(page.hasMore, isTrue);
    expect(page.items, isEmpty);

    final filled = HistoryPageResult(items: [item], hasMore: false);
    expect(filled.items.single.id, '1');
  });

  test('HistorySearchHit preserves match flags', () {
    final hit = HistorySearchHit(
      item: item,
      titleMatched: true,
      summaryMatched: false,
      transcriptMatched: true,
    );
    expect(hit.titleMatched, isTrue);
    expect(hit.summaryMatched, isFalse);
    expect(hit.transcriptMatched, isTrue);
  });

  test('SessionPageResult holds sessions and hasMore', () {
    const session = SessionModel(
      id: 1,
      title: 'S',
      startedAt: 1,
      createdAt: 1,
    );
    const page = SessionPageResult(items: [session], hasMore: true);
    expect(page.items.single.title, 'S');
    expect(page.hasMore, isTrue);
  });
}
