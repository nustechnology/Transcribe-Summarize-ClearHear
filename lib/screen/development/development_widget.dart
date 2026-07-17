import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/development/controllers/development_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/widgets/summary_section.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class DevelopmentView extends GetView<DevelopmentController> {
  const DevelopmentView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.rootDelegate.popRoute();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Get.rootDelegate.popRoute(),
        ),
        title: Text(
          StringKeys.devScreenTitle.tr,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.title,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                StringKeys.devTranscriptInputLabel.tr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.transcriptController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: StringKeys.devTranscriptInputHint.tr,
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                StringKeys.devClippedPreviewLabel.tr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    controller.clippedTranscript.value.isEmpty
                        ? StringKeys.devClippedPreviewEmpty.tr
                        : controller.clippedTranscript.value,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Obx(
                () => FilledButton.icon(
                  onPressed: controller.isProcessing.value
                      ? null
                      : controller.summarize,
                  icon: controller.isProcessing.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    controller.isProcessing.value
                        ? StringKeys.devSummarizeRunning.tr
                        : StringKeys.devSummarizeButton.tr,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Obx(
                () => SummarySection(
                  content: controller.summary.value,
                  isProcessing: controller.isProcessing.value &&
                      controller.summary.value.isEmpty,
                  isFailed: controller.errorMessage.value.isNotEmpty,
                  failureMessage: controller.errorMessage.value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
