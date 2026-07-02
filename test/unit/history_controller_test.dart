import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';

HistoryItem _item(String id, {String title = 'Test session'}) {
  return HistoryItem(
    id: id,
    title: title,
    timestamp: DateTime(2025, 1, 1),
    snippet: 'Snippet for $id',
    duration: 60,
    speakerCount: 1,
    category: 'meeting',
  );
}

void main() {
  group('HistoryController selection', () {
    late HistoryRepository repository;
    late HistoryController controller;

    setUp(() {
      repository = HistoryRepository();
      controller = HistoryController(historyRepository: repository);
      controller.items.addAll([
        _item('a', title: 'Alpha'),
        _item('b', title: 'Beta'),
        _item('c', title: 'Gamma'),
      ]);
    });

    test('enterSelectionMode enables mode and selects item', () {
      controller.enterSelectionMode('a');

      expect(controller.isSelectionMode.value, isTrue);
      expect(controller.isSelected('a'), isTrue);
      expect(controller.selectedCount, 1);
    });

    test('toggleItemSelection adds and removes ids', () {
      controller.enterSelectionMode('a');
      controller.toggleItemSelection('b');
      expect(controller.selectedCount, 2);

      controller.toggleItemSelection('a');
      expect(controller.isSelected('a'), isFalse);
      expect(controller.isSelectionMode.value, isTrue);
    });

    test('toggleItemSelection exits mode when last item deselected', () {
      controller.enterSelectionMode('a');
      controller.toggleItemSelection('a');

      expect(controller.isSelectionMode.value, isFalse);
      expect(controller.selectedCount, 0);
    });

    test('toggleSelectAll selects and deselects filtered items', () {
      controller.searchQuery.value = 'alpha';
      controller.toggleSelectAll();

      expect(controller.isSelectionMode.value, isTrue);
      expect(controller.isSelected('a'), isTrue);
      expect(controller.isSelected('b'), isFalse);

      controller.toggleSelectAll();
      expect(controller.isSelected('a'), isFalse);
      expect(controller.isSelectionMode.value, isFalse);
    });

    test('cancelSelection clears state', () {
      controller.enterSelectionMode('a');
      controller.toggleItemSelection('b');
      controller.cancelSelection();

      expect(controller.isSelectionMode.value, isFalse);
      expect(controller.selectedCount, 0);
    });

    test('loadMoreHistory is blocked while selection mode is active', () async {
      controller.enterSelectionMode('a');
      controller.hasMore.value = true;

      await controller.loadMoreHistory();

      expect(controller.isLoadingMore.value, isFalse);
      expect(controller.items.length, 3);
    });
  });
}
