import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class HistorySearchField extends StatefulWidget {
  const HistorySearchField({super.key});

  @override
  State<HistorySearchField> createState() => _HistorySearchFieldState();
}

class _HistorySearchFieldState extends State<HistorySearchField> {
  final _controller = Get.find<HistoryController>();
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = _controller.searchQuery.value;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

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
          controller: _textController,
          onChanged: _controller.updateSearchQuery,
          readOnly: _controller.isSelectionMode.value,
          enabled: !_controller.isSelectionMode.value,
          decoration: InputDecoration(
            hintText: StringKeys.historySearchHint.tr,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.muted, size: 22),
            suffixIcon: _controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.muted, size: 20),
                    onPressed: () {
                      _textController.clear();
                      _controller.clearSearch();
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
