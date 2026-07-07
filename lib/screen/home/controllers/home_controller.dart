import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../model/conversation_segment.dart';
import '../../../model/transcript_segment_entry.dart';
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
  DateTime? _captioningStartedAt;
  Timer? _durationTimer;
  DateTime? _captioningStartTime;
  Duration _accumulatedDuration = Duration.zero;

  final isCaptioning = false.obs;
  final transcript = ''.obs;
  final transcriptSegments = <TranscriptSegmentEntry>[].obs;
  final summary = ''.obs;
  final isProcessing = false.obs;
  final isPausing = false.obs;
  final isFinishingTranscript = false.obs;
  final isPaused = false.obs;
  final captioningElapsed = Duration.zero.obs;
  final isLoadingTranscript = false.obs;
  final sessionDuration = ''.obs;
  final transcriptFontSize = 20.0.obs;
  final statusMessage = ''.obs;
  final isAsrModelReady = false.obs;
  final isAsrModelLoading = true.obs;

  final transcriptSpeakers = Rx<List<Map<String, dynamic>>>([]);

  /// Live caption state — populated while a session is active or frozen.
  final finalizedParagraphs = <String>[].obs;

  /// Current in-progress (partial) text being spoken right now.
  final partialText = ''.obs;

  /// Normalized audio amplitude 0.0–1.0, updated per PCM chunk (~16ms).
  final audioAmplitude = 0.0.obs;

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
      transcriptSegments.clear();
      isFinishingTranscript.value = false;
      isPaused.value = false;
      isPausing.value = false;
      captioningElapsed.value = Duration.zero;
      _captioningStartedAt = DateTime.now();
      _startDurationTimer();
      transcriptSpeakers.value = [];
      finalizedParagraphs.clear();
      partialText.value = '';

      isCaptioning.value = true;
      _captioningStartTime = DateTime.now();
      _accumulatedDuration = Duration.zero;

      _activeLiveTranscript = _createLiveTranscriptService();
      await _activeLiveTranscript!.start(
        onAmplitude: (amp) => audioAmplitude.value = amp,
        onPartial: (text) {
          partialText.value = text;
        },
        onFinal: (text, isNewParagraph) {
          partialText.value = '';
          if (isNewParagraph && finalizedParagraphs.isNotEmpty) {
            finalizedParagraphs.add(''); // empty string = paragraph break
          }
          finalizedParagraphs.add(text);
        },
      );

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
    isPaused.value = false;
    isPausing.value = false;
    isFinishingTranscript.value = true;
    _stopDurationTimer();
    audioAmplitude.value = 0.0;
    finalizedParagraphs.clear();
    partialText.value = '';

    final liveTranscript = _activeLiveTranscript;
    _activeLiveTranscript = null;

    if (liveTranscript != null) {
      _scheduleFinish(liveTranscript);
    }
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

  void _applyTranscriptResult(LiveTranscriptResult result) {
    transcript.value = result.text;
    transcriptSegments.assignAll(
      transcriptEntriesFromSegments(result.segments),
    );
  }

  Future<void> _finishInBackground(LiveTranscriptService liveTranscript) async {
    statusMessage.value = '';
    try {
      final result = await liveTranscript.finish();
      _applyTranscriptResult(result);
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
      final hasVisibleTranscript =
          transcriptSegments.isNotEmpty || result.text.trim().isNotEmpty;
      if (!hasVisibleTranscript) {
        statusMessage.value = StringKeys.transcriptionFailed;
      }
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Stop failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionFailed;
    } finally {
      isFinishingTranscript.value = false;
      liveTranscript.dispose();
    }
  }

  Future<void> pauseCaptioning() async {
    if (!isCaptioning.value || isPausing.value) return;

    isPausing.value = true;

    // Freeze finalized text, wipe any unfinished partial.
    partialText.value = '';
    audioAmplitude.value = 0.0;

    isPaused.value = true;
    isLoadingTranscript.value = true;

    if (_captioningStartTime != null) {
      _accumulatedDuration += DateTime.now().difference(_captioningStartTime!);
      _captioningStartTime = null;
    }
    sessionDuration.value = _formatDuration(_accumulatedDuration);
    _stopDurationTimer();

    final liveTranscript = _activeLiveTranscript;
    _activeLiveTranscript = null;

    if (liveTranscript == null) {
      isLoadingTranscript.value = false;
      return;
    }

    try {
      final result = await liveTranscript.finish();
      transcript.value = result.text;
      final previousTexts = finalizedParagraphs
          .where((p) => p.isNotEmpty)
          .toList();

      final currentTexts = result.segments
          .where((s) => s.displayText.isNotEmpty)
          .map((s) => s.displayText)
          .toList();

      final allTexts = [...previousTexts, ...currentTexts];
      transcriptSpeakers.value = allTexts
          .asMap()
          .entries
          .map((e) => <String, dynamic>{
                'id': e.key + 1,
                'speaker': 'Speaker',
                'message': e.value,
              })
          .toList();
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Pause finish failed: $error');
      debugPrint('$stackTrace');
    } finally {
      isPausing.value = false;
      isLoadingTranscript.value = false;
      liveTranscript.dispose();
    }
  }

  Future<void> resumeCaptioning() async {
    if (!isCaptioning.value || isPausing.value) return;

    isPausing.value = true;
    isPaused.value = false;
    partialText.value = '';
    if (_captioningStartTime != null) {
      _accumulatedDuration += DateTime.now().difference(_captioningStartTime!);
    }
    _captioningStartTime = DateTime.now();
    _captioningStartedAt = DateTime.now().subtract(captioningElapsed.value);
    _startDurationTimer();

    _activeLiveTranscript = _createLiveTranscriptService();
    try {
      await _activeLiveTranscript!.start(
        onAmplitude: (amp) => audioAmplitude.value = amp,
        onPartial: (text) {
          partialText.value = text;
        },
        onFinal: (text, isNewParagraph) {
          partialText.value = '';
          if (isNewParagraph && finalizedParagraphs.isNotEmpty) {
            finalizedParagraphs.add('');
          }
          finalizedParagraphs.add(text);
        },
      );
      isPausing.value = false;
      debugPrint('[Transcribe] Resumed captioning');
    } catch (error, stackTrace) {
      isPausing.value = false;
      isPaused.value = true;
      debugPrint('[Transcribe] Resume failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionFailed;
      _activeLiveTranscript?.dispose();
      _activeLiveTranscript = null;
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _captioningStartedAt;
      if (!isCaptioning.value || isPaused.value || startedAt == null) return;
      captioningElapsed.value = DateTime.now().difference(startedAt);
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  String get formattedCaptioningElapsed {
    final totalSeconds = captioningElapsed.value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> summarizeTranscript() async {
    // Compute full transcript from live paragraphs or fallback to transcript.
    final liveParagraphs =
        finalizedParagraphs.where((p) => p.isNotEmpty).join('\n');
    final text =
        (liveParagraphs.isNotEmpty ? liveParagraphs : transcript.value).trim();
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
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
    _stopDurationTimer();
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
