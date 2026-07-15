import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../arch/repository/segment_repository.dart';
import '../../../arch/repository/session_repository.dart';
import '../../../model/conversation_segment.dart';
import '../../../model/transcript_segment_entry.dart';
import '../../../arch/repository/settings_repository.dart';
import '../../../lang/string_keys.dart';
import '../../../screen/history/controllers/history_controller.dart';
import '../../../screen/main/controllers/main_controller.dart';
import '../../../service/audio_recorder_service.dart';
import '../../../service/live_transcript_service.dart';
import '../../../service/llama_service.dart';
import '../../../service/whisper_kit_service.dart';
import '../../../shared/caption_size_config.dart';
import '../../../shared/models/settings_model.dart';
import '../../../util/session_segment_mapper.dart';
import '../../../util/toast/app_toast.dart';

class HomeController extends GetxController {
  HomeController({
    SettingsRepository? settingsRepository,
    WhisperKitService? whisperKitService,
    LlamaService? llamaService,
    AudioRecorderService? audioRecorderService,
    LiveTranscriptService? liveTranscriptService,
    SessionRepository? sessionRepository,
    SegmentRepository? segmentRepository,
  })  : _settingsRepository = settingsRepository,
        _whisperKitService = whisperKitService ?? WhisperKitService(),
        _llamaService = llamaService ?? LlamaService(),
        _audioRecorderService =
            audioRecorderService ?? AudioRecorderService(),
        _liveTranscriptService = liveTranscriptService,
        _sessionRepository = sessionRepository,
        _segmentRepository = segmentRepository;

  final SettingsRepository? _settingsRepository;
  final WhisperKitService _whisperKitService;
  final LlamaService _llamaService;
  final AudioRecorderService _audioRecorderService;
  final LiveTranscriptService? _liveTranscriptService;
  final SessionRepository? _sessionRepository;
  final SegmentRepository? _segmentRepository;

  LiveTranscriptService? _activeLiveTranscript;
  Future<void>? _finishFuture;
  DateTime? _captioningStartedAt;
  Timer? _durationTimer;
  List<ConversationSegment> _pendingSaveSegments = const [];
  bool _isSaveSheetVisible = false;
  bool _saveTranscriptsEnabled = SettingsModel.defaults().savingEnabled;
  final Set<int> _finalizedSegmentIds = {};

  final isCaptioning = false.obs;
  final transcript = ''.obs;
  final transcriptSegments = <TranscriptSegmentEntry>[].obs;
  final partialTranscript = ''.obs;
  final summary = ''.obs;
  final isProcessing = false.obs;
  final isPausing = false.obs;
  final isFinishingTranscript = false.obs;
  final isPaused = false.obs;
  final captioningElapsed = Duration.zero.obs;
  final defaultCaptionFontSize = CaptionSizeConfig.defaultSize.obs;
  final transcriptFontSize = CaptionSizeConfig.defaultSize.obs;
  final statusMessage = ''.obs;
  final isAsrModelReady = false.obs;
  final isAsrModelLoading = true.obs;
  final asrModelDownloadProgress = 0.0.obs;
  final showSaveSessionPrompt = false.obs;
  final showMicPermissionPrompt = false.obs;
  final showTranscriptFinishErrorPrompt = false.obs;
  final transcriptFinishError = Rxn<TranscriptFinishError>();
  final isSavingSession = false.obs;

  RecorderController get recorderController =>
      _audioRecorderService.recorderController;

  LiveTranscriptService _createLiveTranscriptService() {
    return _liveTranscriptService ??
        LiveTranscriptService(
          audioRecorderService: _audioRecorderService,
          whisperKitService: _whisperKitService,
          onPartialText: _handlePartialText,
          onSegmentFinalized: _handleSegmentFinalized,
          onBackgroundProcessingChanged: _handleBackgroundProcessingChanged,
        );
  }

  void _handleBackgroundProcessingChanged(bool processing) {
    isProcessing.value = processing;
  }

  String get formattedSessionDurationLabel {
    final totalSeconds = captioningElapsed.value.inSeconds;
    if (totalSeconds >= 60) {
      final minutes = totalSeconds ~/ 60;
      final durationText = minutes == 1
          ? StringKeys.homeSaveSessionDurationOneMinute.tr
          : StringKeys.homeSaveSessionDurationMinutes.trParams({
              'count': '$minutes',
            });
      return StringKeys.homeSaveSessionDuration.trParams({
        'duration': durationText,
      });
    }

    final seconds = totalSeconds < 1 ? 1 : totalSeconds;
    final durationText = StringKeys.homeSaveSessionDurationSeconds.trParams({
      'count': '$seconds',
    });
    return StringKeys.homeSaveSessionDuration.trParams({
      'duration': durationText,
    });
  }

  String get defaultSessionTitle => _sessionTitleForDate(
        _captioningStartedAt ?? DateTime.now(),
        prefixKey: StringKeys.homeSaveSessionDefaultTitle,
      );

  bool tryBeginSaveSheetPresentation() {
    if (_isSaveSheetVisible || !showSaveSessionPrompt.value) {
      return false;
    }
    _isSaveSheetVisible = true;
    return true;
  }

  void endSaveSheetPresentation() {
    _isSaveSheetVisible = false;
  }

  void dismissMicPermissionPrompt() {
    showMicPermissionPrompt.value = false;
  }

  void dismissTranscriptFinishErrorPrompt() {
    showTranscriptFinishErrorPrompt.value = false;
    transcriptFinishError.value = null;
  }

  Future<void> retryCaptioningAfterFinishError() async {
    dismissTranscriptFinishErrorPrompt();
    await startCaptioning();
  }

  Future<void> openMicrophoneSettings() async {
    dismissMicPermissionPrompt();
    await _audioRecorderService.openSystemSettings();
  }

  Future<void> navigateToHistoryAfterSave() => _navigateToHistory();

  void _handlePartialText(String text) {
    partialTranscript.value = text;
  }

  void _handleSegmentFinalized(ConversationSegment segment) {
    if (!_finalizedSegmentIds.add(segment.id)) return;
    if (segment.displayText.isEmpty) return;

    transcriptSegments.add(
      TranscriptSegmentEntry(
        text: segment.displayText,
        recordedAt: segment.recordedAt,
      ),
    );
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_preloadAsrModel());
    unawaited(_loadPersistedSettings());
  }

  Future<void> _loadPersistedSettings() async {
    final repository = _settingsRepository;
    if (repository == null) return;

    try {
      final settings = await repository.loadSettings();
      updateDefaultCaptionFontSize(settings.fontSize);
      updateSaveTranscriptsEnabled(settings.savingEnabled);
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Failed to load settings: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Updates the persisted default and applies it when no live session is active.
  void updateDefaultCaptionFontSize(double size) {
    defaultCaptionFontSize.value = size;
    if (!isCaptioning.value) {
      transcriptFontSize.value = size;
    }
  }

  void updateSaveTranscriptsEnabled(bool enabled) {
    _saveTranscriptsEnabled = enabled;
    if (!enabled && showSaveSessionPrompt.value) {
      _clearPendingSaveState();
    }
  }

  void _resetCaptionFontSize() {
    transcriptFontSize.value = defaultCaptionFontSize.value;
  }

  Future<void> _preloadAsrModel() async {
    isAsrModelLoading.value = true;
    isAsrModelReady.value = false;
    asrModelDownloadProgress.value = 0;
    _whisperKitService.onDownloadProgress = (received, total) {
      if (total <= 0) {
        asrModelDownloadProgress.value = 0.0;
        return;
      }

      final progress = (received / total).clamp(0.0, 1.0);
      asrModelDownloadProgress.value = progress.toDouble();
    };
    try {
      await _whisperKitService.ensureModelReady();
      asrModelDownloadProgress.value = 1;
      isAsrModelReady.value = true;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] WhisperKit preload failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionModelFailed;
    } finally {
      _whisperKitService.onDownloadProgress = null;
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
        showMicPermissionPrompt.value = true;
        return;
      }

      _resetLiveSessionState();
      partialTranscript.value = '';
      _finalizedSegmentIds.clear();
      isFinishingTranscript.value = false;
      isPaused.value = false;
      isPausing.value = false;
      captioningElapsed.value = Duration.zero;
      transcriptFontSize.value = defaultCaptionFontSize.value;

      isCaptioning.value = true;

      _activeLiveTranscript = _createLiveTranscriptService();
      await _activeLiveTranscript!.start();

      _captioningStartedAt = DateTime.now();
      _startDurationTimer();

      debugPrint('[Transcribe] Segment recording started');
    } on MissingPluginException {
      debugPrint('[Transcribe] Recorder unavailable (MissingPluginException)');
      isCaptioning.value = false;
      statusMessage.value = StringKeys.recorderUnavailable;
      final failedTranscript = _activeLiveTranscript;
      _activeLiveTranscript = null;
      if (failedTranscript != null) {
        unawaited(failedTranscript.dispose());
      }
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Start failed: $error');
      debugPrint('$stackTrace');
      isCaptioning.value = false;
      statusMessage.value = StringKeys.transcriptionFailed;
      final failedTranscript = _activeLiveTranscript;
      _activeLiveTranscript = null;
      if (failedTranscript != null) {
        unawaited(failedTranscript.dispose());
      }
    }
  }

  Future<void> stopCaptioning() async {
    if (!isCaptioning.value || isFinishingTranscript.value) return;

    isFinishingTranscript.value = true;
    isCaptioning.value = false;
    summary.value = '';
    statusMessage.value = '';
    isPaused.value = false;
    isPausing.value = false;
    partialTranscript.value = '';
    _stopDurationTimer();
    _resetCaptionFontSize();

    final liveTranscript = _activeLiveTranscript;
    _activeLiveTranscript = null;

    if (liveTranscript == null) {
      debugPrint('[Transcribe] Stop failed: live transcript not active');
      return;
    }

    _scheduleFinish(liveTranscript);
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
    _pendingSaveSegments = List.unmodifiable(result.segments);
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
        _promptTranscriptFinishError(
          result.segments.isEmpty
              ? TranscriptFinishError.tooShort
              : TranscriptFinishError.unrecognized,
        );
      } else if (await _isTranscriptSavingEnabled()) {
        showSaveSessionPrompt.value = true;
      } else {
        _clearPendingSaveState();
      }
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Stop failed: $error');
      debugPrint('$stackTrace');
      _promptTranscriptFinishError(TranscriptFinishError.failed);
    } finally {
      isFinishingTranscript.value = false;
      await liveTranscript.dispose();
    }
  }

  void _promptTranscriptFinishError(TranscriptFinishError error) {
    _clearPendingSaveState();
    _resetLiveSessionState();
    _captioningStartedAt = null;
    captioningElapsed.value = Duration.zero;
    transcriptFinishError.value = error;
    showTranscriptFinishErrorPrompt.value = true;
  }

  void discardPendingSession() {
    if (isSavingSession.value) return;
    showSaveSessionPrompt.value = false;
    _resetLiveSessionState();
    _clearPendingSaveState();
    _captioningStartedAt = null;
    captioningElapsed.value = Duration.zero;
  }

  Future<bool> savePendingSession(String title) async {
    if (isSavingSession.value) return false;
    if (!await _isTranscriptSavingEnabled()) return false;

    final sessionRepo = _sessionRepository;
    final segmentRepo = _segmentRepository;
    final startedAt = _captioningStartedAt;
    if (sessionRepo == null || segmentRepo == null || startedAt == null) {
      AppToast.error(StringKeys.somethingWentWrong.tr);
      return false;
    }

    final transcriptText = transcript.value.trim();
    if (transcriptText.isEmpty && transcriptSegments.isEmpty) {
      discardPendingSession();
      return false;
    }

    isSavingSession.value = true;

    int? sessionId;
    try {
      final resolvedTitle = _resolveSessionTitle(title);
      final startEpoch = startedAt.millisecondsSinceEpoch ~/ 1000;
      final durationSec = captioningElapsed.value.inSeconds;
      final endedAt = startEpoch + durationSec;

      sessionId = await sessionRepo.createSession(
        title: resolvedTitle,
        startedAt: startEpoch,
      );

      await sessionRepo.finishSession(
        id: sessionId,
        endedAt: endedAt,
        durationSec: durationSec,
      );

      final segments = mapConversationSegmentsToModels(
        segments: _pendingSaveSegments,
        sessionId: sessionId,
        sessionStartedAt: startedAt,
        durationSec: durationSec,
        createdAtEpoch: endedAt,
      );

      if (segments.isNotEmpty) {
        await segmentRepo.insertSegments(segments);
      }

      showSaveSessionPrompt.value = false;
      _resetLiveSessionState();
      _clearPendingSaveState();
      _captioningStartedAt = null;
      captioningElapsed.value = Duration.zero;

      AppToast.success(
        StringKeys.homeSaveSessionSuccess.tr,
        subtitle: StringKeys.homeSaveSessionStoredNote.tr,
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Save session failed: $error');
      debugPrint('$stackTrace');
      if (sessionId != null) {
        try {
          await sessionRepo.deleteSession(sessionId);
        } catch (_) {
          debugPrint('[Transcribe] Delete session failed: $error');
        }
      }
      AppToast.error(StringKeys.somethingWentWrong.tr);
      return false;
    } finally {
      isSavingSession.value = false;
    }
  }

  Future<void> _navigateToHistory() async {
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().selectTab(1);
    }

    if (Get.isRegistered<HistoryController>()) {
      await Get.find<HistoryController>().refreshHistory();
    }
  }

  String _resolveSessionTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return _sessionTitleForDate(
      DateTime.now(),
      prefixKey: StringKeys.homeSaveSessionAutoTitle,
    );
  }

  String _sessionTitleForDate(DateTime date, {required String prefixKey}) {
    final formattedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return prefixKey.trParams({'date': formattedDate});
  }

  void _resetLiveSessionState() {
    summary.value = '';
    statusMessage.value = '';
    transcript.value = '';
    transcriptSegments.clear();
    partialTranscript.value = '';
    _finalizedSegmentIds.clear();
  }

  void _clearPendingSaveState() {
    _pendingSaveSegments = const [];
    showSaveSessionPrompt.value = false;
  }

  Future<bool> _isTranscriptSavingEnabled() async {
    final repository = _settingsRepository;
    if (repository == null) return _saveTranscriptsEnabled;

    try {
      final settings = await repository.loadSettings();
      _saveTranscriptsEnabled = settings.savingEnabled;
      return settings.savingEnabled;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Failed to read save-transcripts setting: $error');
      debugPrint('$stackTrace');
      return _saveTranscriptsEnabled;
    }
  }

  Future<void> pauseCaptioning() async {
    if (!isCaptioning.value || isPaused.value || isPausing.value) return;

    final liveTranscript = _activeLiveTranscript;
    if (liveTranscript == null) return;

    isPaused.value = true;
    isPausing.value = true;
    partialTranscript.value = '';
    _stopDurationTimer();
    statusMessage.value = '';

    try {
      await liveTranscript.pause();
      if (!isCaptioning.value) return;

      // Results are delivered incrementally via onSegmentFinalized and
      // onBackgroundProcessingChanged — no need to await full transcription.
      debugPrint('[Transcribe] Paused (returned immediately)');
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Pause failed: $error');
      debugPrint('$stackTrace');
      isPaused.value = false;
      _captioningStartedAt =
          DateTime.now().subtract(captioningElapsed.value);
      _startDurationTimer();
      statusMessage.value = StringKeys.transcriptionFailed;
    } finally {
      isPausing.value = false;
    }
  }

  Future<void> resumeCaptioning() async {
    if (!isCaptioning.value || !isPaused.value || isPausing.value) return;

    final liveTranscript = _activeLiveTranscript;
    if (liveTranscript == null) return;

    isPausing.value = true;
    try {
      await liveTranscript.resume();
      isPaused.value = false;
      statusMessage.value = '';
      _captioningStartedAt =
          DateTime.now().subtract(captioningElapsed.value);
      _startDurationTimer();
      debugPrint('[Transcribe] Resumed captioning');
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Resume failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionFailed;
    } finally {
      isPausing.value = false;
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
    if (!isCaptioning.value) return;
    transcriptFontSize.value = (transcriptFontSize.value + CaptionSizeConfig.step)
        .clamp(CaptionSizeConfig.min, CaptionSizeConfig.max)
        .toDouble();
  }

  void decreaseFontSize() {
    if (!isCaptioning.value) return;
    transcriptFontSize.value = (transcriptFontSize.value - CaptionSizeConfig.step)
        .clamp(CaptionSizeConfig.min, CaptionSizeConfig.max)
        .toDouble();
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
    await _whisperKitService.dispose();
  }
}

enum TranscriptFinishError {
  tooShort,
  unrecognized,
  failed,
}
