import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_titlebar.dart';

import '../../style/theme.dart';
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
        child: const Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  AppTitleBar(
                    showActionIcon: false,
                  ),
                  HistoryTitleBar(),
                  SizedBox(height: 16),
                  HistorySearchField(),
                  SizedBox(height: 16),
                  Expanded(child: HistoryList()),
                  SizedBox(height: 12),
                  HistoryFooterNote(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
