import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/style/app_colors.dart';

class HistoryTitleBar extends GetView<HistoryController> {
  const HistoryTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSelectionMode.value) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              StringKeys.navHistory.tr,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.title,
                letterSpacing: -0.5,
              ),
            ),
          ],
        );
      }

      final canDelete =
          controller.selectedCount > 0 && !controller.isDeleting.value;

      return Row(
        children: [
          InkWell(
            onTap: canDelete ? controller.deleteSelected : null,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_outlined,
                  color: canDelete ? AppColors.title : AppColors.muted,
                ),
                const SizedBox(
                  width: 4.0,
                ),
                Text(
                  StringKeys.historyItemsSelected.trParams({
                    'count': '${controller.selectedCount}',
                  }),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.title,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: controller.toggleSelectAll,
            child: Text(
              controller.isAllFilteredSelected
                  ? StringKeys.historyDeselectAll.tr
                  : StringKeys.historySelectAll.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.cancelSelection,
            child: Text(
              StringKeys.historyCancel.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      );
    });
  }
}
