import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../style/theme.dart';
import '../controllers/home_controller.dart';

class TranscriptCard extends GetView<HomeController> {
  const TranscriptCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCaptioning = controller.isCaptioning.value;
      final isProcessing = controller.isProcessing.value;
      final transcript = controller.transcript.value.trim();
      final summary = controller.summary.value.trim();
      final statusMessage = controller.statusMessage.value;
      final fontSize = controller.transcriptFontSize.value;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isCaptioning ? AppColors.surface : AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: isCaptioning ? Border.all(color: AppColors.border.withOpacity(0.5)) : null,
          boxShadow: isCaptioning
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: _buildContent(
          isCaptioning: isCaptioning,
          isProcessing: isProcessing,
          transcript: transcript,
          summary: summary,
          statusMessage: statusMessage,
          fontSize: fontSize,
        ),
      );
    });
  }

  Widget _buildContent({
    required bool isCaptioning,
    required bool isProcessing,
    required String transcript,
    required String summary,
    required String statusMessage,
    required double fontSize,
  }) {
    if (statusMessage.isNotEmpty) {
      return Align(
        alignment: Alignment.topCenter,
          child: Text(
            StringKeys.t(statusMessage),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFFE53935),
            height: 1.4,
          ),
        ),
      );
    }

    if (isCaptioning ||
        isProcessing ||
        transcript.isNotEmpty ||
        summary.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              StringKeys.homeSpeakerLabel.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.statusIdle,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            if (isProcessing)
              Text(
                StringKeys.homeProcessing.tr,
                style: TextStyle(
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              )
            else if (transcript.isNotEmpty)
              Text(
                transcript,
                style: TextStyle(
                  fontSize: fontSize,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              )
            else
              Text(
                StringKeys.homeListening.tr,
                style: TextStyle(
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                StringKeys.homeSummaryLabel.tr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.statusIdle,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: TextStyle(
                  fontSize: fontSize - 4,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.message_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            StringKeys.homeIdlePromptLine1.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          Text(
            StringKeys.homeIdlePromptLine2.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}