import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';

void main() {
  final item = HistoryItem(
    id: '7',
    title: 'Standup',
    timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
    snippet: 'Hello',
    summaryStatus: 'ready',
    duration: 90,
    speakerCount: 2,
    category: 'session',
  );

  group('HistoryItem', () {
    test('toJson / fromJson round-trip', () {
      final restored = HistoryItem.fromJson(item.toJson());

      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.timestamp, item.timestamp);
      expect(restored.snippet, item.snippet);
      expect(restored.summaryStatus, item.summaryStatus);
      expect(restored.duration, item.duration);
      expect(restored.speakerCount, item.speakerCount);
      expect(restored.category, item.category);
    });

    test('fromJson defaults missing summaryStatus to idle', () {
      final json = item.toJson()..remove('summaryStatus');
      final restored = HistoryItem.fromJson(json);
      expect(restored.summaryStatus, 'idle');
    });

    test('copyWith updates only provided fields', () {
      final updated = item.copyWith(title: 'Retro', speakerCount: 3);
      expect(updated.title, 'Retro');
      expect(updated.speakerCount, 3);
      expect(updated.id, item.id);
      expect(updated.snippet, item.snippet);
    });
  });
}
