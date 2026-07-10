import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({
    super.key,
    required this.content,
    this.isProcessing = false,
    this.isFailed = false,
    this.failureMessage = '',
    this.isRetrying = false,
    this.onRetry,
  });

  final String content;
  final bool isProcessing;
  final bool isFailed;
  final String failureMessage;
  final bool isRetrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.summaryBackgroundStart,
            AppColors.summaryBackgroundEnd,
          ],
        ),
        border: Border.all(
          color: AppColors.summaryBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (content.isNotEmpty) {
      return SelectableText(
        content,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
      );
    }

    if (isFailed) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              failureMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: isRetrying ? null : onRetry,
              icon: isRetrying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(
                isRetrying
                    ? StringKeys.commonRetrying.tr
                    : StringKeys.commonRetry.tr,
              ),
            ),
          ],
        ],
      );
    }

    if (isProcessing) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              StringKeys.historyDetailGeneratingSummary.tr,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      StringKeys.historyDetailPlaceholderSummary.tr,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
        height: 1.5,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.auto_awesome,
          size: 22,
          color: AppColors.summaryPurple,
        ),
        const SizedBox(width: 10),
        Text(
          StringKeys.historyDetailSummaryLabel.tr,
          style: const TextStyle(
            color: AppColors.summaryPurple,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '•',
          style: TextStyle(
            color: AppColors.textDivider,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          StringKeys.historyDetailOnDevice.tr,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        _buildPrivateBadge(),
      ],
    );
  }

  Widget _buildPrivateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
          color: AppColors.privateBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.historyBadgeMeeting,
          )),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            StringKeys.historyDetailPrivate.tr,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
