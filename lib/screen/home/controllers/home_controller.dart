import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../service/audio_recorder_service.dart';
import '../../../service/live_transcript_service.dart';
import '../../../service/llama_service.dart';
import '../../../service/whisper_kit_service.dart';

class HomeController extends GetxController {
  HomeController({
    WhisperKitService? whisperKitService,
    LlamaService? llamaService,
    AudioRecorderService? audioRecorderService,
    LiveTranscriptService? liveTranscriptService,
  })  : _whisperKitService = whisperKitService ?? WhisperKitService(),
        _llamaService = llamaService ?? LlamaService(),
        _audioRecorderService =
            audioRecorderService ?? AudioRecorderService(),
        _liveTranscriptService = liveTranscriptService;

  final WhisperKitService _whisperKitService;
  final LlamaService _llamaService;
  final AudioRecorderService _audioRecorderService;
  final LiveTranscriptService? _liveTranscriptService;

  LiveTranscriptService? _activeLiveTranscript;
  Future<void>? _finishFuture;

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
          whisperKitService: _whisperKitService,
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
      await _whisperKitService.ensureModelReady();
      isAsrModelReady.value = true;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] WhisperKit preload failed: $error');
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
    if (!isAsrModelReady.value) return;
    await _awaitPendingFinish();
    if (isCaptioning.value || _activeLiveTranscript != null) return;

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
      await _activeLiveTranscript!.start();

      debugPrint('[Transcribe] Segment recording started');
    } on MissingPluginException {
      debugPrint('[Transcribe] Recorder unavailable (MissingPluginException)');
      isCaptioning.value = false;
      statusMessage.value = StringKeys.recorderUnavailable;
      _activeLiveTranscript?.dispose();
      _activeLiveTranscript = null;
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

    final liveTranscript = _activeLiveTranscript;
    _activeLiveTranscript = null;

    if (liveTranscript == null) {
      debugPrint('[Transcribe] Stop failed: live transcript not active');
      return;
    }

    _scheduleFinish(liveTranscript);
  }

  Future<void> pauseCaptioning() async {
    // TODO: Implement pause captioning
  }

  void _scheduleFinish(LiveTranscriptService liveTranscript) {
    _finishFuture = (_finishFuture ?? Future<void>.value())
        .then((_) => _finishInBackground(liveTranscript));
  }

  Future<void> _awaitPendingFinish() async {
    final pending = _finishFuture;
    if (pending != null) {
      await pending;
    }
  }

  Future<void> _finishInBackground(LiveTranscriptService liveTranscript) async {
    try {
      final result = await liveTranscript.finish();
      debugPrint(
        '[Transcribe] Stop complete '
        '(${result.segments.length} segments, whisper=${result.usedWhisper})',
      );
      debugPrint('[Transcribe] Whisper text:\n${result.text}');
      for (final segment in result.segments) {
        debugPrint(
          '[Transcribe] segment ${segment.id} '
          'whisper="${segment.whisperText}" wav=${segment.wavPath}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Stop failed: $error');
      debugPrint('$stackTrace');
    } finally {
      liveTranscript.dispose();
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
    unawaited(_tearDown());
    super.onClose();
  }

  Future<void> _tearDown() async {
    final active = _activeLiveTranscript;
    if (active != null) {
      _activeLiveTranscript = null;
      isCaptioning.value = false;
      _scheduleFinish(active);
    }

    await _awaitPendingFinish();

    await _audioRecorderService.dispose();
    _whisperKitService.dispose();
  }
}
