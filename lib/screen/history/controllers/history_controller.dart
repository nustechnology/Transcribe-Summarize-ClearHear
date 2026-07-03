import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';
import 'package:transcribe_summarize_clearhear/utils/logger/app_logger.dart';
import 'package:transcribe_summarize_clearhear/utils/toast/app_toast.dart';

class HistoryController extends GetxController {
  HistoryController({required HistoryRepository historyRepository})
      : _historyRepository = historyRepository;

  static const pageSize = 20;

  final HistoryRepository _historyRepository;

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
    debounce(searchQuery, (_) => _executeSearch(), time: const Duration(milliseconds: 200));
    loadHistory();
  }

  Future<void> _executeSearch() async {
    final query = searchQuery.value.trim();
    if (query.isEmpty) {
      isSearching.value = false;
      searchResults.clear();
      _lastQuery = '';
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    isSearching.value = true;
    final results = await _historyRepository.searchSessions(query);
    searchResults.assignAll(results);
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

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(StringKeys.historyDeleteConfirmTitle
            .trParams({'count': '${selectedIds.length}'})),
        content: Text(StringKeys.historyDeleteConfirmMessage.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(StringKeys.historyCancel.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(StringKeys.historyDeleteConfirmAction.tr),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await executeDeleteSelected();
  }

  Future<void> deleteItem(String id) async {
    isDeleting.value = true;
    try {
      final deletedCount = await _historyRepository.deleteSessions([id]);
      items.removeWhere((item) => item.id == id);
      searchResults.removeWhere((hit) => hit.item.id == id);

      if (deletedCount > 0) {
        AppToast.success(
          StringKeys.historyDeleteSuccess.trParams({
            'count': '1',
          }),
        );
      }
    } catch (e) {
      AppLogger.error(error: e);
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> executeDeleteSelected() async {
    if (selectedIds.isEmpty || isDeleting.value) {
      return;
    }

    final ids = selectedIds.toList();
    isDeleting.value = true;
    try {
      final deletedCount = await _historyRepository.deleteSessions(ids);
      cancelSelection();
      
      if (isSearching.value) {
        searchResults.removeWhere((hit) => ids.contains(hit.item.id));
        items.removeWhere((item) => ids.contains(item.id));
      } else {
        await refreshHistory();
      }

      if (deletedCount > 0) {
        AppToast.success(
          StringKeys.historyDeleteSuccess.trParams({
            'count': '$deletedCount',
          }),
        );
      }
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
      await Future.delayed(const Duration(milliseconds: 2000));
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
      await Future.delayed(const Duration(milliseconds: 2000));
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
    AppLogger.info('Navigate to detail for item $id');
  }

  Future<void> updateTitle(String id, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final oldTitle = items[index].title;
    if (oldTitle == trimmed) return;

    items[index] = items[index].copyWith(title: trimmed);

    final success = await _historyRepository.updateSessionTitle(id, trimmed);
    if (!success) {
      items[index] = items[index].copyWith(title: oldTitle);
    }
  }
}
