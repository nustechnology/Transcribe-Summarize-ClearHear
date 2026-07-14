import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/controllers/session_detail_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/bottom_action_bar.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/empty_widget.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/session_title.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/summary_section.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/transcript_message_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_loading.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';
import 'package:transcribe_summarize_clearhear/util/datetime/datetime_utils.dart';

class SessionDetailView extends GetView<SessionDetailController> {
  const SessionDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isTitleEditing = controller.isTitleEditing.value;

      return PopScope(
        canPop: !isTitleEditing,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            titleSpacing: 0,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap:
                    isTitleEditing ? null : () => Get.rootDelegate.popRoute(),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.primary,
                      size: 20.0,
                    ),
                    Text(
                      StringKeys.navHistory.tr,
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: SafeArea(
            child:
                controller.isLoading.value && controller.session.value == null
                    ? _buildLoadingSkeleton()
                    : _buildContent(context),
          ),
        ),
      );
    });
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _skeletonBox(height: 24, width: 220),
          const SizedBox(height: 8),
          _skeletonBox(height: 14, width: 140),
          const SizedBox(height: 24),
          _skeletonBox(height: 140),
          const SizedBox(height: 24),
          _skeletonBox(height: 18, width: 120),
          const SizedBox(height: 12),
          _skeletonBox(height: 72),
          const SizedBox(height: 12),
          _skeletonBox(height: 72),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double height, double? width}) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(StringKeys.sessionDetailDeleteConfirmTitle.tr),
        content: Text(StringKeys.sessionDetailDeleteConfirmMessage.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(StringKeys.sessionDetailDeleteConfirmCancel.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.stopRed),
            onPressed: () => Get.back(result: true),
            child: Text(StringKeys.sessionDetailDeleteConfirmDelete.tr),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      unawaited(controller.deleteSession());
    }
  }

  Widget _buildContent(BuildContext context) {
    final session = controller.session.value;
    final errorMessage = controller.errorMessage.value;
    final isTitleEditing = controller.isTitleEditing.value;

    if (errorMessage.isNotEmpty || session == null) {
      return EmptyState(
        message: errorMessage.isNotEmpty
            ? errorMessage
            : StringKeys.somethingWentWrong.tr,
        onRetry: controller.loadDetail,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: isTitleEditing
          ? () => FocusManager.instance.primaryFocus?.unfocus()
          : null,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  if (!isTitleEditing) {
                    await controller.loadDetail();
                  }
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (!isTitleEditing &&
                        notification is ScrollUpdateNotification &&
                        notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 160 &&
                        !controller.isLoadingMore.value &&
                        controller.hasMoreSegments.value) {
                      controller.loadSegmentsPage();
                    }
                    return false;
                  },
                  child: ListView(
                    physics: isTitleEditing
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      const SizedBox(height: 8.0),
                      SessionTitle(
                        title: session.title,
                        date: DateTimeUtils.formatSmartTimestamp(
                          DateTime.fromMillisecondsSinceEpoch(
                            session.startedAt * 1000,
                          ),
                        ),
                        duration: DateTimeUtils.formatDurationFromSeconds(
                          session.durationSec,
                        ),
                        onTitleSave: controller.updateTitle,
                        onTitleEditingChanged: controller.setTitleEditing,
                      ),
                      const SizedBox(height: 24),
                      SummarySection(
                        content: controller.summaryText,
                        isProcessing: controller.isShowingSummaryLoading,
                        isFailed: controller.isSummaryFailed,
                        failureMessage: controller.summaryFailureMessage,
                        isRetrying: controller.isRetryingSummary.value,
                        onRetry: controller.retrySummary,
                      ),
                      const SizedBox(height: 24),
                      _TranscriptSection(
                        segments: controller.segments,
                        hasMoreSegments: controller.hasMoreSegments,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: isTitleEditing,
            child: Obx(
              () => BottomActionBar(
                onShare: (sharePositionOrigin) => unawaited(
                  controller.shareTranscript(
                    sharePositionOrigin: sharePositionOrigin,
                  ),
                ),
                onDelete: () => unawaited(_showDeleteConfirmation(context)),
                isSharing: controller.isSharing.value,
                isDeleting: controller.isDeleting.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptSection extends StatelessWidget {
  const _TranscriptSection({
    required this.segments,
    required this.hasMoreSegments,
  });

  final RxList<SegmentModel> segments;
  final RxBool hasMoreSegments;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final currentSegments = segments.toList();
        if (currentSegments.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              StringKeys.historyDetailNoTranscript.tr,
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentSegments.length + (hasMoreSegments.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < currentSegments.length) {
              final segment = currentSegments[index];
              return TranscriptMessageItem(
                time: DateTimeUtils.formatDurationFromSeconds(
                  segment.startMs ~/ 1000,
                ),
                message: segment.text,
              );
            }

            return const Center(child: AppLoading());
          },
        );
      },
    );
  }
}
