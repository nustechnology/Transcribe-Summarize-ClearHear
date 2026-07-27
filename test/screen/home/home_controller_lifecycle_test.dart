import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/model/conversation_segment.dart';
import 'package:transcribe_summarize_clearhear/screen/home/controllers/home_controller.dart';
import 'package:transcribe_summarize_clearhear/service/audio_recorder_service.dart';
import 'package:transcribe_summarize_clearhear/service/live_transcript_service.dart';
import 'package:transcribe_summarize_clearhear/service/sherpa_onnx_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/settings_model.dart';

class _FakeSessionRepository implements SessionRepository {
  static const draftId = 42;

  final List<int> createDraftCalls = [];
  final List<int> deletedIds = [];
  int _nextId = 100;

  @override
  Future<int> createDraftSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) async {
    createDraftCalls.add(startedAt);
    return draftId;
  }

  @override
  Future<int> createSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) async =>
      _nextId++;

  @override
  Future<void> deleteSession(int id) async => deletedIds.add(id);

  @override
  Future<void> markSessionSaved({
    required int id,
    required String title,
    required int endedAt,
    required int durationSec,
  }) async {}

  @override
  Future<void> finishSession({
    required int id,
    required int endedAt,
    required int durationSec,
  }) async {}

  @override
  Future<int> deleteSessions(List<int> ids) => throw UnimplementedError();

  @override
  Future<void> deleteAllSessions() => throw UnimplementedError();

  @override
  Future<List<SessionModel>> getUnsavedSessions() => throw UnimplementedError();

  @override
  Future<SessionModel?> getSession(int id) => throw UnimplementedError();

  @override
  Future<SessionPageResult> getAllSessions({
    required int offset,
    required int limit,
    bool savedOnly = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<SearchResult>> searchSessions(String query, {int limit = 50}) =>
      throw UnimplementedError();

  @override
  Future<void> updateSummary({required int id, required String summary}) =>
      throw UnimplementedError();

  @override
  Future<void> updateTitle({required int id, required String title}) =>
      throw UnimplementedError();
}

class _FakeSegmentRepository implements SegmentRepository {
  final List<SegmentModel> inserted = [];

  @override
  Future<int> insertSegment(SegmentModel segment) async {
    inserted.add(segment);
    return inserted.length;
  }

  @override
  Future<void> insertSegments(List<SegmentModel> segments) async {
    inserted.addAll(segments);
  }

  @override
  Future<List<SegmentModel>> getSegments(int sessionId) =>
      throw UnimplementedError();

  @override
  Future<List<SegmentModel>> getSegmentsPaged({
    required int sessionId,
    required int offset,
    required int limit,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSegments(int sessionId) async {}

  @override
  Future<int> countDistinctSpeakers(int sessionId) async => 0;
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.savingEnabled = true});

  final bool savingEnabled;

  @override
  Future<SettingsModel> loadSettings() async => SettingsModel(
        fontSize: 16,
        savingEnabled: savingEnabled,
        updatedAt: 1,
      );

  @override
  Future<void> saveSettings(SettingsModel settings) async {}

  @override
  Future<void> updateTheme(String theme) async {}

  @override
  Future<void> updateFontSize(double fontSize) async {}

  @override
  Future<void> updateSavingEnabled({required bool enabled}) async {}
}

class _FakeAudioRecorder extends AudioRecorderService {
  bool permissionGranted = true;

  @override
  Future<bool> ensurePermission() async => permissionGranted;

  @override
  Future<void> dispose() async {}
}

class _FakeSherpaService extends SherpaOnnxService {
  @override
  Future<void> ensureModelReady() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeLiveTranscript extends LiveTranscriptService {
  _FakeLiveTranscript({
    required super.audioRecorderService,
    required super.sherpaOnnxService,
  });

  final segments = <ConversationSegment>[];
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int finishCalls = 0;

  @override
  Future<void> start() async {
    startCalls += 1;
  }

  @override
  Future<LiveTranscriptResult> pause() async {
    pauseCalls += 1;
    return LiveTranscriptResult(
      text: segments.map((s) => s.displayText).join('\n'),
      segments: List.of(segments),
      usedAsr: true,
    );
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
  }

  @override
  Future<LiveTranscriptResult> finish() async {
    finishCalls += 1;
    return LiveTranscriptResult(
      text: segments.map((s) => s.displayText).join('\n'),
      segments: List.of(segments),
      usedAsr: true,
    );
  }

  @override
  Future<LiveTranscriptResult> refineSpeakerLabels({
    bool clearAudioAfter = true,
  }) async {
    return LiveTranscriptResult(
      text: segments.map((s) => s.displayText).join('\n'),
      segments: List.of(segments),
      usedAsr: true,
    );
  }

  @override
  Future<void> dispose() async {}

  void emitSegment(String text, {int id = 1}) {
    final segment = ConversationSegment(
      id: id,
      asrText: text,
      recordedAt: DateTime.now(),
      speakerLabel: 'Speaker 1',
    );
    segments.add(segment);
    onSegmentFinalized?.call(segment);
  }

  void emitPartial(String text) => onPartialText?.call(text);
}

HomeController _build({
  required _FakeSessionRepository sessions,
  required _FakeSegmentRepository segments,
  required _FakeLiveTranscript live,
  required _FakeAudioRecorder audio,
  required _FakeSherpaService sherpa,
  _FakeSettingsRepository? settings,
}) {
  return HomeController(
    settingsRepository: settings ?? _FakeSettingsRepository(),
    sessionRepository: sessions,
    segmentRepository: segments,
    audioRecorderService: audio,
    sherpaOnnxService: sherpa,
    liveTranscriptService: live,
  );
}

Future<void> _awaitFinish(HomeController controller) async {
  for (var i = 0; i < 50 && controller.isFinishingTranscript.value; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  late _FakeSessionRepository sessions;
  late _FakeSegmentRepository segmentRepo;
  late _FakeAudioRecorder audio;
  late _FakeSherpaService sherpa;
  late _FakeLiveTranscript live;
  late HomeController controller;

  setUp(() {
    sessions = _FakeSessionRepository();
    segmentRepo = _FakeSegmentRepository();
    audio = _FakeAudioRecorder();
    sherpa = _FakeSherpaService();
    live = _FakeLiveTranscript(
      audioRecorderService: audio,
      sherpaOnnxService: sherpa,
    );
    controller = _build(
      sessions: sessions,
      segments: segmentRepo,
      live: live,
      audio: audio,
      sherpa: sherpa,
    );
    controller.isAsrModelReady.value = true;
    controller.updateSaveTranscriptsEnabled(true);
  });

  test('startCaptioning begins session and wires live transcript', () async {
    await controller.startCaptioning();

    expect(controller.isCaptioning.value, isTrue);
    expect(live.startCalls, 1);
    expect(controller.isPaused.value, isFalse);
  });

  test('startCaptioning shows mic prompt when permission denied', () async {
    audio.permissionGranted = false;

    await controller.startCaptioning();

    expect(controller.isCaptioning.value, isFalse);
    expect(controller.showMicPermissionPrompt.value, isTrue);
    expect(live.startCalls, 0);
  });

  test('finalized segments persist to draft when saving enabled', () async {
    await controller.startCaptioning();
    live.emitSegment('hello world', id: 1);
    await Future<void>.delayed(Duration.zero);

    expect(controller.transcriptSegments, hasLength(1));
    expect(sessions.createDraftCalls, hasLength(1));
    expect(segmentRepo.inserted, hasLength(1));
    expect(segmentRepo.inserted.single.text, 'hello world');
    expect(segmentRepo.inserted.single.sessionId, _FakeSessionRepository.draftId);
  });

  test('partial text updates live partialTranscript', () async {
    await controller.startCaptioning();
    live.emitPartial('he');
    expect(controller.partialTranscript.value, 'he');
  });

  test('pause and resume captioning', () async {
    await controller.startCaptioning();
    live.emitSegment('paused bit', id: 1);

    await controller.pauseCaptioning();
    expect(controller.isPaused.value, isTrue);
    expect(live.pauseCalls, 1);
    expect(controller.transcript.value, contains('paused bit'));

    await controller.resumeCaptioning();
    expect(controller.isPaused.value, isFalse);
    expect(live.resumeCalls, 1);
  });

  test('stopCaptioning finishes and prompts save when enabled', () async {
    await controller.startCaptioning();
    live.emitSegment('final line', id: 1);

    await controller.stopCaptioning();
    await _awaitFinish(controller);

    expect(controller.isCaptioning.value, isFalse);
    expect(live.finishCalls, 1);
    expect(controller.showSaveSessionPrompt.value, isTrue);
    expect(controller.transcriptSegments, isNotEmpty);
  });

  test('stopCaptioning does not prompt save when setting disabled', () async {
    controller = _build(
      sessions: sessions,
      segments: segmentRepo,
      live: live,
      audio: audio,
      sherpa: sherpa,
      settings: _FakeSettingsRepository(savingEnabled: false),
    );
    controller.isAsrModelReady.value = true;
    controller.updateSaveTranscriptsEnabled(false);

    await controller.startCaptioning();
    live.emitSegment('unsaved', id: 1);

    await controller.stopCaptioning();
    await _awaitFinish(controller);

    expect(controller.showSaveSessionPrompt.value, isFalse);
  });

  test('stopCaptioning with empty transcript shows finish error prompt',
      () async {
    await controller.startCaptioning();

    await controller.stopCaptioning();
    await _awaitFinish(controller);

    expect(controller.showSaveSessionPrompt.value, isFalse);
    expect(controller.showTranscriptFinishErrorPrompt.value, isTrue);
    expect(
      controller.transcriptFinishError.value,
      TranscriptFinishError.tooShort,
    );
  });

  test('duplicate finalized segment id is ignored', () async {
    await controller.startCaptioning();
    live.emitSegment('once', id: 7);
    live.emitSegment('once again', id: 7);
    await Future<void>.delayed(Duration.zero);

    expect(controller.transcriptSegments, hasLength(1));
    expect(controller.transcriptSegments.single.text, 'once');
  });

  test('discardPendingSession deletes draft', () async {
    await controller.startCaptioning();
    live.emitSegment('to discard', id: 1);
    await Future<void>.delayed(Duration.zero);

    await controller.stopCaptioning();
    await _awaitFinish(controller);
    expect(controller.showSaveSessionPrompt.value, isTrue);

    controller.discardPendingSession();
    await Future<void>.delayed(Duration.zero);

    expect(controller.showSaveSessionPrompt.value, isFalse);
    expect(sessions.deletedIds, contains(_FakeSessionRepository.draftId));
  });

  test('updateDefaultCaptionFontSize applies when idle', () {
    controller.updateDefaultCaptionFontSize(18);
    expect(controller.defaultCaptionFontSize.value, 18);
    expect(controller.transcriptFontSize.value, 18);
  });

  test('formattedCaptioningElapsed pads seconds', () {
    controller.captioningElapsed.value = const Duration(minutes: 1, seconds: 5);
    expect(controller.formattedCaptioningElapsed, '1:05');
  });
}
