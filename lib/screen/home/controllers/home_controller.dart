import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
import '../../../service/foreground_service_handler.dart';
import '../../../service/live_transcript_service.dart';
import '../../../service/llama_service.dart';
import '../../../service/sherpa_onnx_service.dart';
import '../../../service/speaker_diarization_service.dart';
import '../../../shared/caption_size_config.dart';
import '../../../shared/models/segment_model.dart';
import '../../../shared/models/settings_model.dart';
import '../../../util/session_segment_mapper.dart';
import '../../../util/toast/app_toast.dart';

class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController({
    SettingsRepository? settingsRepository,
    SherpaOnnxService? sherpaOnnxService,
    SpeakerDiarizationService? speakerDiarizationService,
    LlamaService? llamaService,
    AudioRecorderService? audioRecorderService,
    LiveTranscriptService? liveTranscriptService,
    SessionRepository? sessionRepository,
    SegmentRepository? segmentRepository,
  })  : _settingsRepository = settingsRepository,
        _sherpaOnnxService = sherpaOnnxService ?? SherpaOnnxService(),
        _speakerDiarizationService =
            speakerDiarizationService ?? SpeakerDiarizationService(),
        _llamaService = llamaService ?? LlamaService(),
        _audioRecorderService = audioRecorderService ?? AudioRecorderService(),
        _liveTranscriptService = liveTranscriptService,
        _sessionRepository = sessionRepository,
        _segmentRepository = segmentRepository;

  final SettingsRepository? _settingsRepository;
  final SherpaOnnxService _sherpaOnnxService;
  final SpeakerDiarizationService _speakerDiarizationService;
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
  Future<int>? _draftSessionFuture;
  final List<Future<void>> _pendingDraftWrites = [];

  /// When false, live draft segment inserts are ignored (stop/save in progress).
  bool _draftPersistsEnabled = true;

  final isCaptioning = false.obs;
  final transcript = ''.obs;
  final transcriptSegments = <TranscriptSegmentEntry>[].obs;
  final partialTranscript = ''.obs;

  /// Speaker label for the utterance currently being transcribed; null
  /// means "not yet determined" (shown as "Unknown" while enough audio is
  /// still being gathered for a reliable embedding).
  final partialSpeakerLabel = Rxn<String>();
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
    final service = _liveTranscriptService ??
        LiveTranscriptService(
          audioRecorderService: _audioRecorderService,
          sherpaOnnxService: _sherpaOnnxService,
          speakerDiarizationService: _speakerDiarizationService,
          onPartialText: _handlePartialText,
          onPartialSpeakerLabel: _handlePartialSpeakerLabel,
          onSegmentFinalized: _handleSegmentFinalized,
        );
    service.onPartialText = _handlePartialText;
    service.onSegmentFinalized = _handleSegmentFinalized;
    return service;
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

  void _handlePartialSpeakerLabel(String? label) {
    partialSpeakerLabel.value = label;
  }

  void _handleSegmentFinalized(ConversationSegment segment) {
    if (!_finalizedSegmentIds.add(segment.id)) return;
    if (segment.displayText.isEmpty) return;

    transcriptSegments.add(
      TranscriptSegmentEntry(
        text: segment.displayText,
        recordedAt: segment.recordedAt,
        speakerLabel: segment.speakerLabel,
      ),
    );

    final write = _persistSegmentToDraft(segment);
    _pendingDraftWrites.add(write);
    unawaited(write.whenComplete(() => _pendingDraftWrites.remove(write)));
  }

  Future<int?> _ensureDraftSession() async {
    final sessionRepo = _sessionRepository;
    final startedAt = _captioningStartedAt;
    if (sessionRepo == null || startedAt == null) return null;

    _draftSessionFuture ??= sessionRepo.createDraftSession(
      title: _resolveSessionTitle(''),
      startedAt: startedAt.millisecondsSinceEpoch ~/ 1000,
    );
    return _draftSessionFuture;
  }

  Future<void> _persistSegmentToDraft(ConversationSegment segment) async {
    if (!_draftPersistsEnabled) return;
    final segmentRepo = _segmentRepository;
    final startedAt = _captioningStartedAt;
    if (segmentRepo == null || startedAt == null) return;
    if (!_saveTranscriptsEnabled) return;

    try {
      final sessionId = await _ensureDraftSession();
      if (sessionId == null || !_draftPersistsEnabled) return;

      final offsetMs = segment.recordedAt.millisecondsSinceEpoch -
          startedAt.millisecondsSinceEpoch;
      final startMs = offsetMs < 0 ? 0 : offsetMs;

      await segmentRepo.insertSegment(
        SegmentModel(
          sessionId: sessionId,
          startMs: startMs,
          endMs: startMs,
          text: segment.displayText,
          createdAt: segment.recordedAt.millisecondsSinceEpoch ~/ 1000,
          speakerLabel: segment.speakerLabel,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Draft persist failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _discardDraft() async {
    final future = _draftSessionFuture;
    _draftSessionFuture = null;
    if (future == null) return;

    final sessionRepo = _sessionRepository;
    if (sessionRepo == null) return;

    try {
      if (_pendingDraftWrites.isNotEmpty) {
        await Future.wait(List.of(_pendingDraftWrites));
      }
      final id = await future;
      await sessionRepo.deleteSession(id);
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Draft discard failed: $error');
      debugPrint('$stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[Lifecycle] state=$state isCaptioning=${isCaptioning.value}');
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
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
    _sherpaOnnxService.onDownloadProgress = (_, received, total) {
      if (total <= 0) return;
      asrModelDownloadProgress.value =
          (received / total).clamp(0.0, 1.0).toDouble();
    };
    try {
      await _sherpaOnnxService.ensureModelReady();
      asrModelDownloadProgress.value = 1;
      isAsrModelReady.value = true;
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] SherpaOnnx preload failed: $error');
      debugPrint('$stackTrace');
      statusMessage.value = StringKeys.transcriptionModelFailed;
    } finally {
      _sherpaOnnxService.onDownloadProgress = null;
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
      _draftSessionFuture = null;
      _draftPersistsEnabled = true;
      isFinishingTranscript.value = false;
      isPaused.value = false;
      isPausing.value = false;
      captioningElapsed.value = Duration.zero;
      transcriptFontSize.value = defaultCaptionFontSize.value;

      isCaptioning.value = true;

      _activeLiveTranscript = _createLiveTranscriptService();
      await _activeLiveTranscript!.start();

      unawaited(ForegroundServiceHandler.start());

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

    // Stop accepting draft writes before flush/finalize so late inserts
    // cannot race with save's delete+reinsert and duplicate rows.
    _draftPersistsEnabled = false;

    isFinishingTranscript.value = true;
    isCaptioning.value = false;
    summary.value = '';
    statusMessage.value = '';
    isPaused.value = false;
    isPausing.value = false;
    partialTranscript.value = '';
    partialSpeakerLabel.value = null;
    _stopDurationTimer();
    _resetCaptionFontSize();

    unawaited(ForegroundServiceHandler.stop());

    final liveTranscript = _activeLiveTranscript;
    _activeLiveTranscript = null;

    if (liveTranscript == null) {
      debugPrint('[Transcribe] Stop failed: live transcript not active');
      isFinishingTranscript.value = false;
      return;
    }

    // Let the stop loading indicator mount/paint before finish work starts.
    await Future<void>.delayed(Duration.zero);
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
      // Fast path: flush ASR only so the stop spinner can paint/animate.
      final result = await liveTranscript.finish();
      _applyTranscriptResult(result);

      // Re-label from retained PCM. Yields between segments so Cam++
      // does not freeze the isolate; clears audioSamples when finished.
      final refined = await liveTranscript.refineSpeakerLabels();
      _applyTranscriptResult(refined);

      final hasVisibleTranscript =
          transcriptSegments.isNotEmpty || refined.text.trim().isNotEmpty;
      if (!hasVisibleTranscript) {
        _promptTranscriptFinishError(
          refined.segments.isEmpty
              ? TranscriptFinishError.tooShort
              : TranscriptFinishError.unrecognized,
        );
      } else if (await _isTranscriptSavingEnabled()) {
        showSaveSessionPrompt.value = true;
      } else {
        _clearPendingSaveState();
      }

      debugPrint(
        '[Transcribe] Stop complete '
        '(${refined.segments.length} segments, asr=${refined.usedAsr})',
      );
      if (kDebugMode) {
        debugPrint('[Transcribe] ASR text:\n${refined.text}');
        for (final segment in refined.segments) {
          debugPrint(
            '[Transcribe] segment ${segment.id} '
            'asr="${segment.asrText}" speaker=${segment.speakerLabel}',
          );
        }
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
    unawaited(_discardDraft());
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
    unawaited(_discardDraft());
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
    // Let the sheet save spinner paint before DB work.
    await Future<void>.delayed(Duration.zero);
    // Finish any in-flight stop work so save doesn't contend with dispose.
    await _awaitPendingFinish();

    try {
      final resolvedTitle = _resolveSessionTitle(title);
      final startEpoch = startedAt.millisecondsSinceEpoch ~/ 1000;
      final durationSec = captioningElapsed.value.inSeconds;
      final endedAt = startEpoch + durationSec;

      final promoted = await _promoteDraftToSaved(
        sessionRepo: sessionRepo,
        segmentRepo: segmentRepo,
        startedAt: startedAt,
        title: resolvedTitle,
        endedAt: endedAt,
        durationSec: durationSec,
      );

      if (!promoted) {
        await _saveAsNewSession(
          sessionRepo: sessionRepo,
          segmentRepo: segmentRepo,
          startedAt: startedAt,
          title: resolvedTitle,
          startEpoch: startEpoch,
          durationSec: durationSec,
          endedAt: endedAt,
        );
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
      AppToast.error(StringKeys.somethingWentWrong.tr);
      return false;
    } finally {
      isSavingSession.value = false;
    }
  }

  Future<bool> _promoteDraftToSaved({
    required SessionRepository sessionRepo,
    required SegmentRepository segmentRepo,
    required DateTime startedAt,
    required String title,
    required int endedAt,
    required int durationSec,
  }) async {
    final future = _draftSessionFuture;
    if (future == null) return false;

    _draftPersistsEnabled = false;
    if (_pendingDraftWrites.isNotEmpty) {
      await Future.wait(List.of(_pendingDraftWrites));
    }
    // Drain any write that started just before the flag flipped.
    if (_pendingDraftWrites.isNotEmpty) {
      await Future.wait(List.of(_pendingDraftWrites));
    }

    final draftId = await future;

    // Always replace draft rows with the in-memory finalized set so we never
    // keep live draft inserts alongside the save payload (duplicates).
    await segmentRepo.deleteSegments(draftId);
    final segments = mapConversationSegmentsToModels(
      segments: _pendingSaveSegments,
      sessionId: draftId,
      sessionStartedAt: startedAt,
      durationSec: durationSec,
      createdAtEpoch: endedAt,
    );
    if (segments.isNotEmpty) {
      const chunkSize = 40;
      for (var i = 0; i < segments.length; i += chunkSize) {
        await Future<void>.delayed(Duration.zero);
        final end = i + chunkSize < segments.length
            ? i + chunkSize
            : segments.length;
        await segmentRepo.insertSegments(segments.sublist(i, end));
      }
    }

    await sessionRepo.markSessionSaved(
      id: draftId,
      title: title,
      endedAt: endedAt,
      durationSec: durationSec,
    );
    _draftSessionFuture = null;
    return true;
  }

  Future<void> _saveAsNewSession({
    required SessionRepository sessionRepo,
    required SegmentRepository segmentRepo,
    required DateTime startedAt,
    required String title,
    required int startEpoch,
    required int durationSec,
    required int endedAt,
  }) async {
    int? sessionId;
    try {
      sessionId = await sessionRepo.createSession(
        title: title,
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
        const chunkSize = 40;
        for (var i = 0; i < segments.length; i += chunkSize) {
          await Future<void>.delayed(Duration.zero);
          final end = i + chunkSize < segments.length
              ? i + chunkSize
              : segments.length;
          await segmentRepo.insertSegments(segments.sublist(i, end));
        }
      }

      await _discardDraft();
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Save-as-new session failed: $error');
      debugPrint('$stackTrace');
      if (sessionId != null) {
        try {
          await sessionRepo.deleteSession(sessionId);
        } catch (_) {
          debugPrint('[Transcribe] Delete session failed after save error');
        }
      }
      rethrow;
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
    partialSpeakerLabel.value = null;
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
      debugPrint(
          '[Transcribe] Failed to read save-transcripts setting: $error');
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
    partialSpeakerLabel.value = null;
    _stopDurationTimer();
    statusMessage.value = '';

    try {
      final result = await liveTranscript.pause();
      if (!isCaptioning.value) return;

      _applyTranscriptResult(result);
      debugPrint(
        '[Transcribe] Paused '
        '(${result.segments.length} segments, asr=${result.usedAsr})',
      );
      debugPrint('[Transcribe] Paused text:\n${result.text}');
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Pause failed: $error');
      debugPrint('$stackTrace');
      isPaused.value = false;
      _captioningStartedAt = DateTime.now().subtract(captioningElapsed.value);
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
      _captioningStartedAt = DateTime.now().subtract(captioningElapsed.value);
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
    transcriptFontSize.value =
        (transcriptFontSize.value + CaptionSizeConfig.step)
            .clamp(CaptionSizeConfig.min, CaptionSizeConfig.max)
            .toDouble();
  }

  void decreaseFontSize() {
    if (!isCaptioning.value) return;
    transcriptFontSize.value =
        (transcriptFontSize.value - CaptionSizeConfig.step)
            .clamp(CaptionSizeConfig.min, CaptionSizeConfig.max)
            .toDouble();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ForegroundServiceHandler.stop());
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
    await _sherpaOnnxService.dispose();
    await _speakerDiarizationService.dispose();
  }
}

enum TranscriptFinishError {
  tooShort,
  unrecognized,
  failed,
}
