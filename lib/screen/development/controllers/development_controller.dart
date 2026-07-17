import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../service/llama_service.dart';
import '../../../service/summary_prompt.dart';

class DevelopmentController extends GetxController {
  DevelopmentController({required LlamaService llamaService})
      : _llamaService = llamaService;

  final LlamaService _llamaService;
  final transcriptController = TextEditingController();

  final clippedTranscript = ''.obs;
  final summary = ''.obs;
  final isProcessing = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    transcriptController.addListener(_updateClippedPreview);
    _updateClippedPreview();
  }

  void _updateClippedPreview() {
    clippedTranscript.value = clipTranscriptForSummary(transcriptController.text);
  }

  Future<void> summarize() async {
    final transcript = transcriptController.text.trim();
    if (transcript.isEmpty || isProcessing.value) return;

    isProcessing.value = true;
    errorMessage.value = '';
    summary.value = '';

    try {
      if (!_llamaService.isModelLoaded) {
        final loaded = await _llamaService.loadBundledModel(onProgress: (_) {});
        if (!loaded) {
          errorMessage.value = StringKeys.summaryModelFailed.tr;
          return;
        }
      }

      // Use summarize() (not stream) so output goes through the same
      // markdown/label sanitizer as production SessionSummaryService.
      summary.value = await _llamaService.summarize(transcript);
    } catch (error) {
      errorMessage.value = StringKeys.summaryFailed.tr;
    } finally {
      isProcessing.value = false;
    }
  }

  @override
  void onClose() {
    transcriptController.dispose();
    super.onClose();
  }
}
