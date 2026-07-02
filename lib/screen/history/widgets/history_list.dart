import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_loading.dart';
import 'package:transcribe_summarize_clearhear/style/app_colors.dart';
import 'history_card.dart';

class HistoryList extends GetView<HistoryController> {
  const HistoryList({super.key});

  static const _loadMoreThreshold = 100.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: AppLoading());
      }

      final items = controller.filteredItems;
      if (items.isEmpty) {
        return Center(
          child: Text(
            StringKeys.historyNoResults.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.muted,
            ),
          ),
        );
      }

      final showLoadMoreIndicator = controller.isLoadingMore.value;
      final isSelectionMode = controller.isSelectionMode.value;

      return RefreshIndicator(
        onRefresh: () async {
          controller.cancelSelection();
          await controller.refreshHistory();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (isSelectionMode) {
              return false;
            }
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - _loadMoreThreshold) {
              controller.loadMoreHistory();
            }
            return false;
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length + (showLoadMoreIndicator ? 1 : 0),
            separatorBuilder: (_, index) {
              if (showLoadMoreIndicator && index >= items.length - 1) {
                return const SizedBox.shrink();
              }
              return const SizedBox(height: 16);
            },
            itemBuilder: (_, index) {
              if (index >= items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: AppLoading()),
                );
              }

              final item = items[index];
              return Dismissible(
                key: ValueKey('dismiss_${item.id}'),
                direction: isSelectionMode 
                    ? DismissDirection.none 
                    : DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) {
                  controller.deleteItem(item.id);
                },
                child: HistoryCard(
                  key: ValueKey(item.id),
                  item: item,
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
