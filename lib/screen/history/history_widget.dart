import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_titlebar.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

import 'controllers/history_controller.dart';
import 'widgets/history_footer_note.dart';
import 'widgets/history_header.dart';
import 'widgets/history_list.dart';
import 'widgets/history_search_field.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: !controller.isSelectionMode.value,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && controller.isSelectionMode.value) {
            controller.cancelSelection();
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  AppTitleBar(
                    onActionPressed:
                        controller.isSelectionMode.value ? null : () {},
                    actionIcon: controller.isSelectionMode.value
                        ? null
                        : Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.filter_alt_outlined,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                  ),
                  const HistoryTitleBar(),
                  const SizedBox(height: 16),
                  const HistorySearchField(),
                  const SizedBox(height: 16),
                  const Expanded(child: HistoryList()),
                  const SizedBox(height: 12),
                  const HistoryFooterNote(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
