import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';

void main() {
  group('HistoryRepository', () {
    late HistoryRepository repository;

    setUp(() {
      repository = HistoryRepository();
    });

    test('fetchSessions returns paginated slice', () async {
      final page1 = await repository.fetchSessions(offset: 0, limit: 20);
      expect(page1.items.length, 20);
      expect(page1.hasMore, isTrue);

      final page2 = await repository.fetchSessions(offset: 20, limit: 20);
      expect(page2.items.length, 20);
      expect(page2.hasMore, isTrue);

      final page3 = await repository.fetchSessions(offset: 40, limit: 20);
      expect(page3.items.length, 5);
      expect(page3.hasMore, isFalse);
    });

    test('deleteSessions removes items by id', () async {
      final deleted = await repository.deleteSessions(['item-1', 'item-2']);

      expect(deleted, 2);

      final page = await repository.fetchSessions(offset: 0, limit: 50);
      expect(page.items.length, 43);
      expect(page.items.any((item) => item.id == 'item-1'), isFalse);
      expect(page.items.any((item) => item.id == 'item-2'), isFalse);
    });

    test('deleteSessions returns zero for empty ids', () async {
      final deleted = await repository.deleteSessions([]);
      expect(deleted, 0);
    });
  });
}
