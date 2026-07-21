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

class _MarkSavedCall {
  _MarkSavedCall({required this.id, required this.title});

  final int id;
  final String title;
}

class _FakeSessionRepository implements SessionRepository {
  static const draftId = 99;

  final List<int> createSessionCalls = [];
  final List<int> createDraftCalls = [];
  final List<_MarkSavedCall> markSavedCalls = [];
  int _nextSessionId = 100;

  @override
  Future<int> createSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) async {
    createSessionCalls.add(startedAt);
    return _nextSessionId++;
  }

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
  Future<void> markSessionSaved({
    required int id,
    required String title,
    required int endedAt,
    required int durationSec,
  }) async {
    markSavedCalls.add(_MarkSavedCall(id: id, title: title));
  }

  @override
  Future<void> finishSession({
    required int id,
    required int endedAt,
    required int durationSec,
  }) async {}

  @override
  Future<void> deleteSession(int id) async {}

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
  int _nextId = 1;

  @override
  Future<int> insertSegment(SegmentModel segment) async {
    inserted.add(segment);
    return _nextId++;
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
  Future<void> deleteSegments(int sessionId) => throw UnimplementedError();
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<SettingsModel> loadSettings() async => SettingsModel.defaults();

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
  @override
  Future<bool> ensurePermission() async => true;

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

  @override
  Future<void> start() async {}

  void emitSegment(String text) {
    onSegmentFinalized?.call(
      ConversationSegment(id: 1, asrText: text, recordedAt: DateTime.now()),
    );
  }
}

HomeController _buildController({
  required _FakeSessionRepository sessionRepo,
  required _FakeSegmentRepository segmentRepo,
  required _FakeLiveTranscript live,
  required _FakeAudioRecorder audio,
  required _FakeSherpaService sherpa,
}) {
  return HomeController(
    settingsRepository: _FakeSettingsRepository(),
    sessionRepository: sessionRepo,
    segmentRepository: segmentRepo,
    audioRecorderService: audio,
    sherpaOnnxService: sherpa,
    liveTranscriptService: live,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  tearDown(Get.reset);

  test('save promotes the existing draft instead of creating a new session',
      () async {
    final sessionRepo = _FakeSessionRepository();
    final segmentRepo = _FakeSegmentRepository();
    final audio = _FakeAudioRecorder();
    final sherpa = _FakeSherpaService();
    final live = _FakeLiveTranscript(
      audioRecorderService: audio,
      sherpaOnnxService: sherpa,
    );
    final controller = _buildController(
      sessionRepo: sessionRepo,
      segmentRepo: segmentRepo,
      live: live,
      audio: audio,
      sherpa: sherpa,
    );

    controller.isAsrModelReady.value = true;
    controller.updateSaveTranscriptsEnabled(true);

    await controller.startCaptioning();
    live.emitSegment('hello world');

    final saved = await controller.savePendingSession('My Title');

    expect(saved, isTrue);
    expect(sessionRepo.createDraftCalls, hasLength(1));
    expect(sessionRepo.markSavedCalls, hasLength(1));
    expect(sessionRepo.markSavedCalls.single.id, _FakeSessionRepository.draftId);
    expect(sessionRepo.markSavedCalls.single.title, 'My Title');
    expect(sessionRepo.createSessionCalls, isEmpty);
  });

  test('save falls back to a new session when no draft exists', () async {
    final sessionRepo = _FakeSessionRepository();
    final segmentRepo = _FakeSegmentRepository();
    final audio = _FakeAudioRecorder();
    final sherpa = _FakeSherpaService();
    final live = _FakeLiveTranscript(
      audioRecorderService: audio,
      sherpaOnnxService: sherpa,
    );
    final controller = _buildController(
      sessionRepo: sessionRepo,
      segmentRepo: segmentRepo,
      live: live,
      audio: audio,
      sherpa: sherpa,
    );

    controller.isAsrModelReady.value = true;
    controller.updateSaveTranscriptsEnabled(true);

    await controller.startCaptioning();
    controller.transcript.value = 'hello world';

    final saved = await controller.savePendingSession('Fallback Title');

    expect(saved, isTrue);
    expect(sessionRepo.createDraftCalls, isEmpty);
    expect(sessionRepo.createSessionCalls, hasLength(1));
    expect(sessionRepo.markSavedCalls, isEmpty);
  });
}
