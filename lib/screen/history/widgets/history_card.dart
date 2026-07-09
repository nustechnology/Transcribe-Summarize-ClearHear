import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/highlighted_text.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/inline_editable_title.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';
import 'package:transcribe_summarize_clearhear/util/datetime/datetime_utils.dart';

class HistoryCategories {
  static const meeting = 'meeting';
}

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
                                searchKeyword: controller.searchQuery.value,
                                onSave: (newTitle) =>
                                    controller.updateTitle(item.id, newTitle),
                                onTapSelectionMode: () =>
                                    controller.toggleItemSelection(item.id),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateTimeUtils.formatSmartTimestamp(
                                    item.timestamp,
                                    isFullDateFormat:
                                        controller.isSearching.value),
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
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: HighlightedText(
                        text: item.snippet,
                        keyword: controller.searchQuery.value,
                        enabled: controller.isSearching.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.body,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    HistoryMetadataChip(
                      icon: Icons.access_time,
                      text: DateTimeUtils.formatDurationFromSeconds(
                          item.duration),
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
  const HistoryBadge({
    required this.category,
    super.key,
  });

  final String category;

  @override
  Widget build(BuildContext context) {
    final badgeStyle = _badgeStyleForCategory(category);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: badgeStyle.backgroundColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Icon(badgeStyle.icon, color: badgeStyle.iconColor, size: 22),
    );
  }

  _BadgeStyle _badgeStyleForCategory(String category) {
    switch (category.toLowerCase()) {
      case HistoryCategories.meeting:
        return const _BadgeStyle(
          backgroundColor: AppColors.statusIdle,
          icon: Icons.history_edu,
          iconColor: AppColors.surface,
        );
      default:
        return _BadgeStyle(
          backgroundColor:
              AppColors.historyBadgeMeeting.withValues(alpha: 0.6),
          icon: Icons.people_alt,
          iconColor: AppColors.accent,
        );
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
}

class HistoryMetadataChip extends StatelessWidget {
  const HistoryMetadataChip(
      {required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
