import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/style/app_colors.dart';
import 'package:transcribe_summarize_clearhear/utils/datetime/datetime_utils.dart';

class HistoryCard extends GetView<HistoryController> {
  const HistoryCard({required this.item, super.key});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelectionMode = controller.isSelectionMode.value;
      final isSelected = controller.isSelected(item.id);

      return InkWell(
        onTap: () {
          if (isSelectionMode) {
            controller.toggleItemSelection(item.id);
          } else {
            controller.openDetail(item.id);
          }
        },
        onLongPress: () {
          if (!isSelectionMode) {
            controller.enterSelectionMode(item.id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.05)
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 12),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (_) => controller.toggleItemSelection(item.id),
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HistoryBadge(category: item.category),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InlineEditableTitle(
                                initialTitle: item.title,
                                isSelectionMode: isSelectionMode,
                                onSave: (newTitle) =>
                                    controller.updateTitle(item.id, newTitle),
                                onTapSelectionMode: () =>
                                    controller.toggleItemSelection(item.id),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateTimeUtils.formatSmartTimestamp(
                                    item.timestamp),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.body,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        HistoryMetadataChip(
                          icon: Icons.access_time,
                          text: DateTimeUtils.formatDurationFromSeconds(
                              item.duration),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 1,
                          height: 14,
                          color: Colors.grey.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 10),
                        HistoryMetadataChip(
                          icon: Icons.people_alt,
                          text:
                              '${item.speakerCount} ${StringKeys.homeSpeakerLabel.tr.toLowerCase()}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class HistoryBadge extends StatelessWidget {
  const HistoryBadge({required this.category, super.key});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: const Icon(Icons.people_alt, color: AppColors.primary, size: 22),
    );
  }
}

class HistoryMetadataChip extends StatelessWidget {
  const HistoryMetadataChip(
      {required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class InlineEditableTitle extends StatefulWidget {
  const InlineEditableTitle({
    super.key,
    required this.initialTitle,
    required this.isSelectionMode,
    required this.onSave,
    required this.onTapSelectionMode,
  });

  final String initialTitle;
  final bool isSelectionMode;
  final ValueChanged<String> onSave;
  final VoidCallback onTapSelectionMode;

  @override
  State<InlineEditableTitle> createState() => _InlineEditableTitleState();
}

class _InlineEditableTitleState extends State<InlineEditableTitle> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialTitle);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant InlineEditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTitle != widget.initialTitle && !_isEditing) {
      _textController.text = widget.initialTitle;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _saveAndExit();
    }
  }

  void _saveAndExit() {
    if (!_isEditing) return;

    final newTitle = _textController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.initialTitle) {
      widget.onSave(newTitle);
    }

    setState(() {
      _isEditing = false;
      _textController.text = newTitle.isEmpty ? widget.initialTitle : newTitle;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _textController,
        focusNode: _focusNode,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.title,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _saveAndExit(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (widget.isSelectionMode) {
                widget.onTapSelectionMode();
                return;
              }
              setState(() {
                _isEditing = true;
                _textController.text = widget.initialTitle;
              });
              _focusNode.requestFocus();
            },
            child: Text(
              widget.initialTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.title,
              ),
            ),
          ),
        ),
        const SizedBox(
          width: 2.0,
        ),
        const Icon(
          Icons.arrow_forward_ios,
          size: 16.0,
        )
      ],
    );
  }
}
