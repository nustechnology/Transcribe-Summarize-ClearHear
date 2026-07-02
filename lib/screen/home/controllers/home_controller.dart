import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../service/audio_recorder_service.dart';
import '../../../service/live_transcript_service.dart';
import '../../../service/llama_service.dart';
import '../../../service/sherpa_onnx_service.dart';

class HomeController extends GetxController {
  HomeController({
    SherpaOnnxService? sherpaOnnxService,
    LlamaService? llamaService,
    AudioRecorderService? audioRecorderService,
    LiveTranscriptService? liveTranscriptService,
  })  : _sherpaOnnxService = sherpaOnnxService ?? SherpaOnnxService(),
        _llamaService = llamaService ?? LlamaService(),
        _audioRecorderService =
            audioRecorderService ?? AudioRecorderService(),
        _liveTranscriptService = liveTranscriptService;

  final SherpaOnnxService _sherpaOnnxService;
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
  final isAsrModelReady = false.obs;
  final isAsrModelLoading = true.obs;

  LiveTranscriptService _createLiveTranscriptService() {
    return _liveTranscriptService ??
        LiveTranscriptService(
          audioRecorderService: _audioRecorderService,
          sherpaOnnxService: _sherpaOnnxService,
        );
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_preloadAsrModel());
  }

  Future<void> _preloadAsrModel() async {
    isAsrModelLoading.value = true;
    try {
      await _sherpaOnnxService.ensureModelReady();
      isAsrModelReady.value = true;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Sherpa model preload failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionModelFailed;
    } finally {
      isAsrModelLoading.value = false;
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
    if (isProcessing.value || !isAsrModelReady.value) return;

    try {
      final hasPermission = await _audioRecorderService.ensurePermission();
      if (!hasPermission) {
        statusMessage.value = StringKeys.microphonePermissionDenied;
        return;
      }

      statusMessage.value = '';
      summary.value = '';
      transcript.value = '';

      isCaptioning.value = true;

      _activeLiveTranscript = _createLiveTranscriptService();
      await _activeLiveTranscript!.start(
        onUpdate: (fullText) => transcript.value = fullText,
      );

      debugPrint('[Transcribe] Realtime streaming started');
    } on MissingPluginException {
      debugPrint('[Transcribe] Recorder unavailable (MissingPluginException)');
      isCaptioning.value = false;
      statusMessage.value = StringKeys.recorderUnavailable;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Start failed: $error');
      debugPrint('$stackTrace');
      isCaptioning.value = false;
      statusMessage.value = StringKeys.transcriptionFailed;
      _activeLiveTranscript?.dispose();
      _activeLiveTranscript = null;
    }
  }

  Future<void> stopCaptioning() async {
    if (!isCaptioning.value) return;

    isCaptioning.value = false;
    summary.value = '';
    statusMessage.value = '';

    try {
      final liveTranscript = _activeLiveTranscript;
      if (liveTranscript == null) {
        debugPrint('[Transcribe] Stop failed: live transcript not active');
        statusMessage.value = StringKeys.transcriptionFailed;
        return;
      }

      final result = await liveTranscript.finish(
        onUpdate: (fullText) => transcript.value = fullText,
      );
      transcript.value = result;
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
    statusMessage.value = '';
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
    _sherpaOnnxService.dispose();
    super.onClose();
  }
}
