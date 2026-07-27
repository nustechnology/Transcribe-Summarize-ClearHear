import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_page_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';

HistoryItem _item(String id, {String title = 'Session'}) {
  return HistoryItem(
    id: id,
    title: title,
    timestamp: DateTime(2026, 1, 1),
    snippet: 'snippet',
    summaryStatus: 'ready',
    duration: 60,
    speakerCount: 1,
    category: 'session',
  );
}

class _FakeHistoryRepository extends HistoryRepository {
  _FakeHistoryRepository()
      : super(
          sessionRepository: _UnusedSessionRepository(),
          segmentRepository: _UnusedSegmentRepository(),
        );

  final List<HistoryItem> allItems = [];
  int? forcedPageSize;
  List<HistorySearchHit> searchHits = [];
  int? deleteCountOverride;
  final List<List<String>> deletedBatches = [];
  final List<({String id, String title})> titleUpdates = [];
  bool updateTitleSuccess = true;

  @override
  Future<HistoryPageResult> fetchSessions({
    required int offset,
    required int limit,
  }) async {
    final effectiveLimit = forcedPageSize ?? limit;
    final items = allItems.skip(offset).take(effectiveLimit).toList();
    return HistoryPageResult(
      items: items,
      hasMore: offset + items.length < allItems.length,
    );
  }

  @override
  Future<List<HistorySearchHit>> searchSessions(String query) async =>
      searchHits;

  @override
  Future<int> deleteSessions(List<String> ids) async {
    deletedBatches.add(ids);
    return deleteCountOverride ?? ids.length;
  }

  @override
  Future<bool> updateSessionTitle(String id, String newTitle) async {
    titleUpdates.add((id: id, title: newTitle));
    return updateTitleSuccess;
  }

  @override
  Future<HistoryItem?> getSession(String id) async => null;
}

class _UnusedSessionRepository implements SessionRepository {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedSegmentRepository implements SegmentRepository {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  late _FakeHistoryRepository repository;
  late HistoryController controller;

  setUp(() async {
    repository = _FakeHistoryRepository();
    repository.allItems.addAll([_item('1'), _item('2')]);
    controller = HistoryController(historyRepository: repository);
    Get.put(controller);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(Get.reset);

  test('loadHistory populates items from repository', () async {
    expect(controller.items.map((e) => e.id), ['1', '2']);
    expect(controller.isLoading.value, isFalse);
    expect(controller.hasMore.value, isFalse);
  });

  test('loadMoreHistory appends the next page', () async {
    repository.allItems.addAll([_item('3'), _item('4')]);
    repository.forcedPageSize = 2;
    await controller.loadHistory();

    expect(controller.items.map((e) => e.id), ['1', '2']);
    expect(controller.hasMore.value, isTrue);

    await controller.loadMoreHistory();

    expect(controller.items.map((e) => e.id), ['1', '2', '3', '4']);
    expect(controller.hasMore.value, isFalse);
  });

  test('selection mode toggles and select-all works', () {
    controller.enterSelectionMode('1');
    expect(controller.isSelectionMode.value, isTrue);
    expect(controller.isSelected('1'), isTrue);

    controller.toggleItemSelection('2');
    expect(controller.selectedCount, 2);
    expect(controller.isAllFilteredSelected, isTrue);

    controller.toggleSelectAll();
    expect(controller.selectedIds, isEmpty);
    expect(controller.isSelectionMode.value, isFalse);
  });

  test('executeDeleteSelected clears selection after delete', () async {
    controller.enterSelectionMode('1');
    controller.toggleItemSelection('2');

    await controller.executeDeleteSelected();

    expect(repository.deletedBatches.single, ['1', '2']);
    expect(controller.isSelectionMode.value, isFalse);
  });

  test('updateTitle optimistically updates then persists', () async {
    await controller.updateTitle('1', 'Renamed');
    expect(controller.items.firstWhere((e) => e.id == '1').title, 'Renamed');
    expect(repository.titleUpdates.single.title, 'Renamed');
  });

  test('updateTitle rolls back when repository fails', () async {
    repository.updateTitleSuccess = false;
    await controller.updateTitle('1', 'Will Fail');
    expect(controller.items.firstWhere((e) => e.id == '1').title, 'Session');
  });

  test('clearSearch resets search state', () {
    controller.isSearching.value = true;
    controller.searchResults.add(
      HistorySearchHit(
        item: _item('9'),
        titleMatched: true,
        summaryMatched: false,
        transcriptMatched: false,
      ),
    );
    controller.searchQuery.value = 'hello';

    controller.clearSearch();

    expect(controller.isSearching.value, isFalse);
    expect(controller.searchResults, isEmpty);
    expect(controller.searchQuery.value, isEmpty);
  });

  test('removeItem drops local rows', () {
    controller.removeItem('1');
    expect(controller.items.map((e) => e.id), ['2']);
  });

  test('cancelSelection clears selected ids', () {
    controller.enterSelectionMode('1');
    controller.cancelSelection();
    expect(controller.isSelectionMode.value, isFalse);
    expect(controller.selectedIds, isEmpty);
  });

  test('updateSearchQuery debounces into searchResults', () async {
    repository.searchHits = [
      HistorySearchHit(
        item: _item('1', title: 'Matched'),
        titleMatched: true,
        summaryMatched: false,
        transcriptMatched: false,
      ),
    ];

    controller.updateSearchQuery('Matched');
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(controller.isSearching.value, isTrue);
    expect(controller.searchResults, hasLength(1));
    expect(controller.searchResults.single.item.title, 'Matched');
  });

  test('deleteItem returns true when repository deletes a row', () async {
    final ok = await controller.deleteItem('1');

    expect(ok, isTrue);
    expect(repository.deletedBatches.single, ['1']);
  });
}
