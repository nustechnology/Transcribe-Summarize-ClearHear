import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/style/app_colors.dart';

class HistorySearchField extends GetView<HistoryController> {
  const HistorySearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          onChanged: controller.updateSearchQuery,
          readOnly: controller.isSelectionMode.value,
          enabled: !controller.isSelectionMode.value,
          decoration: InputDecoration(
            hintText: StringKeys.historySearchHint.tr,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.muted, size: 22),
          ),
        ),
      ),
    );
  }
}
