import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../service/audio_recorder_service.dart';
import '../../../service/live_transcript_service.dart';
import '../../../service/llama_service.dart';
import '../../../service/whisper_service.dart';

class HomeController extends GetxController {
  HomeController({
    WhisperService? whisperService,
    LlamaService? llamaService,
    AudioRecorderService? audioRecorderService,
    LiveTranscriptService? liveTranscriptService,
  })  : _whisperService = whisperService ?? WhisperService(),
        _llamaService = llamaService ?? LlamaService(),
        _audioRecorderService =
            audioRecorderService ?? AudioRecorderService(),
        _liveTranscriptService = liveTranscriptService;

  final WhisperService _whisperService;
  final LlamaService _llamaService;
  final AudioRecorderService _audioRecorderService;
  final LiveTranscriptService? _liveTranscriptService;

  LiveTranscriptService? _activeLiveTranscript;

  final isCaptioning = false.obs;
  final transcript = ''.obs;
  final summary = ''.obs;
  final isProcessing = false.obs;
  final transcriptFontSize = 20.0.obs;
  final statusMessage = ''.obs;
  final isWhisperModelReady = false.obs;
  final isWhisperModelLoading = true.obs;

  LiveTranscriptService _createLiveTranscriptService() {
    return _liveTranscriptService ??
        LiveTranscriptService(
          audioRecorderService: _audioRecorderService,
          whisperService: _whisperService,
        );
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_preloadWhisperModel());
  }

  Future<void> _preloadWhisperModel() async {
    isWhisperModelLoading.value = true;
    try {
      await _whisperService.ensureModelReady();
      isWhisperModelReady.value = true;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Whisper model preload failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionModelFailed;
    } finally {
      isWhisperModelLoading.value = false;
    }
  }

  Future<void> toggleCaptioning() async {
    if (isCaptioning.value) {
      await stopCaptioning();
    } else {
      await startCaptioning();
    }
  }

  Future<void> startCaptioning() async {
    if (isProcessing.value || !isWhisperModelReady.value) return;

    try {
      final hasPermission = await _audioRecorderService.ensurePermission();
      if (!hasPermission) {
        statusMessage.value = StringKeys.microphonePermissionDenied;
        return;
      }

      statusMessage.value = '';
      summary.value = '';
      transcript.value = '';

      final recordingPath = await _audioRecorderService.startRecording();
      isCaptioning.value = true;

      _activeLiveTranscript = _createLiveTranscriptService();
      await _activeLiveTranscript!.start(
        onUpdate: (fullText) => transcript.value = fullText,
      );

      debugPrint('[Transcribe] Live recording started: $recordingPath');
    } on MissingPluginException {
      debugPrint('[Transcribe] Recorder unavailable (MissingPluginException)');
      statusMessage.value = StringKeys.recorderUnavailable;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Start failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionFailed;
      _activeLiveTranscript?.dispose();
      _activeLiveTranscript = null;
    }
  }

  Future<void> stopCaptioning() async {
    if (!isCaptioning.value) return;

    isCaptioning.value = false;
    transcript.value = '';
    summary.value = '';
    isProcessing.value = true;
    statusMessage.value = StringKeys.homeProcessing;

    try {
      final liveTranscript = _activeLiveTranscript;
      if (liveTranscript == null) {
        debugPrint('[Transcribe] Stop failed: live transcript not active');
        return;
      }

      final result = await liveTranscript.finish();
      debugPrint('[Transcribe] Final transcript:\n$result');
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Stop failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionFailed;
    } finally {
      _activeLiveTranscript?.dispose();
      _activeLiveTranscript = null;
      isProcessing.value = false;
      statusMessage.value = '';
    }
  }

  Future<void> summarizeTranscript() async {
    final text = transcript.value.trim();
    if (text.isEmpty || isProcessing.value) return;

    isProcessing.value = true;
    statusMessage.value = StringKeys.homeProcessing;
    summary.value = '';

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

      await for (final chunk in _llamaService.summarizeStream(text)) {
        summary.value += chunk;
        debugPrint('[Summary] chunk: $chunk');
      }
      debugPrint('[Summary] final:\n${summary.value}');
    } catch (error, stackTrace) {
      debugPrint('[Summary] failed: $error');
      debugPrint('$stackTrace');
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
    _activeLiveTranscript?.dispose();
    _audioRecorderService.dispose();
    super.onClose();
  }
}
