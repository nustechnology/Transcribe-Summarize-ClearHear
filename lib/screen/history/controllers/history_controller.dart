import 'dart:async';

import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/route/app_route.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';
import 'package:transcribe_summarize_clearhear/util/toast/app_toast.dart';

class HistoryController extends GetxController {
  HistoryController({
    required HistoryRepository historyRepository,
    SessionSummaryService? summaryService,
  })  : _historyRepository = historyRepository,
        _summaryService = summaryService ??
            (Get.isRegistered<SessionSummaryService>()
                ? Get.find<SessionSummaryService>()
                : null);

  static const pageSize = 20;

  final HistoryRepository _historyRepository;
  final SessionSummaryService? _summaryService;

  final items = <HistoryItem>[].obs;
  final searchQuery = ''.obs;
  final isSearching = false.obs;
  final searchResults = <HistorySearchHit>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final isSelectionMode = false.obs;
  final selectedIds = RxSet<String>();
  final isDeleting = false.obs;

  String _lastQuery = '';

  int _offset = 0;
  StreamSubscription<int>? _summaryUpdatesSub;

  int get selectedCount => selectedIds.length;

  bool isSelected(String id) => selectedIds.contains(id);

  bool get isAllFilteredSelected {
    final visible = filteredItems;
    return visible.isNotEmpty &&
        visible.every((item) => selectedIds.contains(item.id));
  }

  List<HistoryItem> get filteredItems {
    if (isSearching.value) {
      return searchResults.map((hit) => hit.item).toList();
    }
    return items;
  }

  @override
  void onInit() {
    super.onInit();
    debounce(searchQuery, (_) => _executeSearch(),
        time: const Duration(milliseconds: 200));
    _bindSummaryUpdates();
    loadHistory();
  }

  @override
  void onClose() {
    _summaryUpdatesSub?.cancel();
    super.onClose();
  }

  Future<void> _executeSearch() async {
    try {
      final query = searchQuery.value.trim();
      if (query.isEmpty) {
        isSearching.value = false;
        searchResults.clear();
        _lastQuery = '';
        return;
      }

      if (query == _lastQuery) return;
      isSearching.value = true;
      final submittedQuery = query;
      final results = await _historyRepository.searchSessions(submittedQuery);
      if (searchQuery.value.trim() == submittedQuery) {
        searchResults.assignAll(results);
        _lastQuery = submittedQuery;
      }
    } catch (e) {
      AppLogger.error(error: e);
    }
  }

  void clearSearch() {
    searchQuery.value = '';
    isSearching.value = false;
    searchResults.clear();
    _lastQuery = '';
  }

  void enterSelectionMode(String itemId) {
    isSelectionMode.value = true;
    selectedIds.add(itemId);
  }

  void toggleItemSelection(String itemId) {
    if (selectedIds.contains(itemId)) {
      selectedIds.remove(itemId);
      if (selectedIds.isEmpty) {
        isSelectionMode.value = false;
      }
    } else {
      selectedIds.add(itemId);
    }
  }

  void toggleSelectAll() {
    final visible = filteredItems;
    if (visible.isEmpty) {
      return;
    }

    if (isAllFilteredSelected) {
      for (final item in visible) {
        selectedIds.remove(item.id);
      }
      if (selectedIds.isEmpty) {
        isSelectionMode.value = false;
      }
    } else {
      isSelectionMode.value = true;
      for (final item in visible) {
        selectedIds.add(item.id);
      }
    }
  }

  void cancelSelection() {
    isSelectionMode.value = false;
    selectedIds.clear();
  }

  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty || isDeleting.value) {
      return;
    }

    await executeDeleteSelected();
  }

  Future<bool> deleteItem(String id) async {
    if (isDeleting.value) {
      return false;
    }

    isDeleting.value = true;

    try {
      final deletedCount = await _historyRepository.deleteSessions([id]);

      if (deletedCount > 0) {
        AppToast.success(
          StringKeys.historyDeleteSuccess.trParams({
            'count': '1',
          }),
          subtitle: StringKeys.historyDeleteRemovedNote.tr,
        );

        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error(error: e);
      AppToast.error(StringKeys.somethingWentWrong.tr);
      return false;
    } finally {
      isDeleting.value = false;
    }
  }

  void removeItem(String id) {
    items.removeWhere((item) => item.id == id);
    searchResults.removeWhere((hit) => hit.item.id == id);
    _offset = items.length;
  }

  Future<void> executeDeleteSelected() async {
    try {
      if (selectedIds.isEmpty || isDeleting.value) {
        return;
      }
      final ids = selectedIds.toList();
      isDeleting.value = true;

      final deletedCount = await _historyRepository.deleteSessions(ids);

      if (deletedCount == 0) {
        AppToast.error(StringKeys.somethingWentWrong.tr);
        return;
      }
      cancelSelection();

      if (deletedCount == ids.length) {
        if (isSearching.value) {
          searchResults.removeWhere((hit) => ids.contains(hit.item.id));
          items.removeWhere((item) => ids.contains(item.id));
          _offset = items.length;
        } else {
          await refreshHistory();
        }
        AppToast.success(
          StringKeys.historyDeleteSuccess.trParams({
            'count': '$deletedCount',
          }),
          subtitle: StringKeys.historyDeleteRemovedNote.tr,
        );
      } else {
        // Partial failure: refresh to reconcile local state with DB.
        await refreshHistory();
        AppToast.warning('Deleted $deletedCount of ${ids.length} items');
      }
    } catch (e) {
      AppLogger.error(error: e);
      AppToast.error(StringKeys.somethingWentWrong.tr);
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> refreshHistory() async {
    await loadHistory();
  }

  Future<void> loadHistory() async {
    _resetPagination();
    isLoading.value = true;
    try {
      final result = await _historyRepository.fetchSessions(
        offset: 0,
        limit: pageSize,
      );
      items.assignAll(result.items);
      _offset = result.items.length;
      hasMore.value = result.hasMore;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMoreHistory() async {
    if (!hasMore.value ||
        isLoading.value ||
        isLoadingMore.value ||
        isSelectionMode.value ||
        isSearching.value) {
      return;
    }
    AppLogger.info(
        "[loadMoreHistory] - hasMore:$hasMore - PageSize:$pageSize _offset:$_offset");
    isLoadingMore.value = true;
    try {
      final result = await _historyRepository.fetchSessions(
        offset: _offset,
        limit: pageSize,
      );
      items.addAll(result.items);
      _offset += result.items.length;
      hasMore.value = result.hasMore;
    } finally {
      isLoadingMore.value = false;
    }
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  void _resetPagination() {
    cancelSelection();
    _offset = 0;
    hasMore.value = true;
    items.clear();
  }

  void openDetail(String id) {
    if (isSelectionMode.value) return;
    Get.rootDelegate.toNamed(
      AppRoutes.sessionDetailPath(id),
      parameters: {'id': id},
    );
  }

  void _bindSummaryUpdates() {
    final service = _summaryService;
    if (service == null) return;

    _summaryUpdatesSub = service.updates.listen((sessionId) {
      final id = '$sessionId';
      final itemIndex = items.indexWhere((item) => item.id == id);
      final searchIndex = searchResults.indexWhere((hit) => hit.item.id == id);

      if (itemIndex == -1 && searchIndex == -1) return;
      unawaited(_refreshSessionPreview(id, itemIndex, searchIndex));
    });
  }

  Future<void> _refreshSessionPreview(
    String id,
    int itemIndex,
    int searchIndex,
  ) async {
    final updated = await _historyRepository.getSession(id);
    if (updated == null) return;

    if (itemIndex != -1) {
      items[itemIndex] = updated;
    }
    if (searchIndex != -1) {
      final hit = searchResults[searchIndex];
      searchResults[searchIndex] = HistorySearchHit(
        item: updated,
        titleMatched: hit.titleMatched,
        summaryMatched: hit.summaryMatched,
        transcriptMatched: hit.transcriptMatched,
      );
    }
  }

  Future<void> updateTitle(String id, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    final itemIndex = items.indexWhere((item) => item.id == id);
    final searchIndex = searchResults.indexWhere((hit) => hit.item.id == id);
    if (itemIndex == -1 && searchIndex == -1) return;

    final oldTitle = itemIndex != -1
        ? items[itemIndex].title
        : searchResults[searchIndex].item.title;
    if (oldTitle == trimmed) return;

    if (itemIndex != -1) {
      items[itemIndex] = items[itemIndex].copyWith(title: trimmed);
    }
    if (searchIndex != -1) {
      final hit = searchResults[searchIndex];
      searchResults[searchIndex] = HistorySearchHit(
        item: hit.item.copyWith(title: trimmed),
        titleMatched: hit.titleMatched,
        summaryMatched: hit.summaryMatched,
        transcriptMatched: hit.transcriptMatched,
      );
    }

    try {
      final success = await _historyRepository.updateSessionTitle(id, trimmed);
      if (!success) throw Exception('updateSessionTitle returned false');
    } catch (e) {
      AppLogger.error(error: e);
      if (itemIndex != -1) {
        items[itemIndex] = items[itemIndex].copyWith(title: oldTitle);
      }
      if (searchIndex != -1) {
        final hit = searchResults[searchIndex];
        searchResults[searchIndex] = HistorySearchHit(
          item: hit.item.copyWith(title: oldTitle),
          titleMatched: hit.titleMatched,
          summaryMatched: hit.summaryMatched,
          transcriptMatched: hit.transcriptMatched,
        );
      }
    }
  }
}
