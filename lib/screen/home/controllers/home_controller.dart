import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../service/audio_recorder_service.dart';
import '../../../service/llama_service.dart';
import '../../../service/whisper_service.dart';

class HomeController extends GetxController {
  HomeController({
    WhisperService? whisperService,
    LlamaService? llamaService,
    AudioRecorderService? audioRecorderService,
  })  : _whisperService = whisperService ?? WhisperService(),
        _llamaService = llamaService ?? LlamaService(),
        _audioRecorderService =
            audioRecorderService ?? AudioRecorderService();

  final WhisperService _whisperService;
  final LlamaService _llamaService;
  final AudioRecorderService _audioRecorderService;

  final isCaptioning = false.obs;
  final transcript = ''.obs;
  final summary = ''.obs;
  final isProcessing = false.obs;
  final transcriptFontSize = 26.0.obs;
  final statusMessage = ''.obs;
  final selectedNavIndex = 0.obs;

  String? _recordingPath;

  Future<void> toggleCaptioning() async {
    if (isCaptioning.value) {
      await stopCaptioning();
    } else {
      await startCaptioning();
    }
  }

  Future<void> startCaptioning() async {
    if (isProcessing.value) return;

    try {
      final hasPermission = await _audioRecorderService.ensurePermission();
      if (!hasPermission) {
        statusMessage.value = StringKeys.microphonePermissionDenied;
        return;
      }

      statusMessage.value = '';
      summary.value = '';
      transcript.value = '';
      _recordingPath = await _audioRecorderService.startRecording();
      isCaptioning.value = true;
    } on MissingPluginException {
      statusMessage.value = StringKeys.recorderUnavailable;
    } catch (_) {
      statusMessage.value = StringKeys.transcriptionFailed;
    }
  }

  Future<void> stopCaptioning() async {
    if (!isCaptioning.value) return;

    isCaptioning.value = false;
    isProcessing.value = true;
    statusMessage.value = StringKeys.homeProcessing;

    try {
      final path = await _audioRecorderService.stopRecording();
      final audioPath = path ?? _recordingPath;
      if (audioPath == null || audioPath.isEmpty) return;

      transcript.value = await _whisperService.transcribeFile(audioPath);
    } catch (_) {
      statusMessage.value = StringKeys.transcriptionFailed;
    } finally {
      isProcessing.value = false;
      statusMessage.value = '';
      _recordingPath = null;
    }
  }

  Future<void> summarizeTranscript() async {
    final text = transcript.value.trim();
    if (text.isEmpty || isProcessing.value) return;

    isProcessing.value = true;
    statusMessage.value = StringKeys.homeProcessing;

    try {
      if (!_llamaService.isModelLoaded) {
        final loaded = await _llamaService.loadDefaultModel(
          onProgress: (_) {},
        );
        if (!loaded) {
          statusMessage.value = StringKeys.summaryModelFailed;
          return;
        }
      }

      summary.value = await _llamaService.summarize(text);
    } catch (_) {
      statusMessage.value = StringKeys.summaryFailed;
    } finally {
      isProcessing.value = false;
      if (summary.value.isNotEmpty) {
        statusMessage.value = '';
      }
    }
  }

  void increaseFontSize() {
    if (transcriptFontSize.value < 36) {
      transcriptFontSize.value += 2;
    }
  }

  void decreaseFontSize() {
    if (transcriptFontSize.value > 18) {
      transcriptFontSize.value -= 2;
    }
  }

  @override
  void onClose() {
    _audioRecorderService.dispose();
    super.onClose();
  }
}
