import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_detail_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/controllers/session_detail_controller.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/service/llama_service.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';
import 'package:transcribe_summarize_clearhear/service/share_service.dart';
import 'package:transcribe_summarize_clearhear/service/transcript_export_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository(this.session);

  SessionModel? session;
  final List<({int id, String title})> titleUpdates = [];
  bool failTitleUpdate = false;
  bool failDelete = false;

  @override
  Future<SessionModel?> getSession(int id) async =>
      session?.id == id ? session : null;

  @override
  Future<void> updateTitle({required int id, required String title}) async {
    if (failTitleUpdate) throw Exception('title failed');
    titleUpdates.add((id: id, title: title));
    session = session?.copyWith(title: title);
  }

  @override
  Future<void> deleteSession(int id) async {
    if (failDelete) throw Exception('delete failed');
    session = null;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSegmentRepository implements SegmentRepository {
  _FakeSegmentRepository(this.segments);

  final List<SegmentModel> segments;

  @override
  Future<List<SegmentModel>> getSegmentsPaged({
    required int sessionId,
    required int offset,
    required int limit,
  }) async {
    return segments
        .where((s) => s.sessionId == sessionId)
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<List<SegmentModel>> getSegments(int sessionId) async =>
      segments.where((s) => s.sessionId == sessionId).toList();

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeExportService extends TranscriptExportService {
  _FakeExportService({this.file});

  final File? file;

  @override
  Future<File> exportTextFile({
    required SessionModel session,
    required SegmentPageLoader loadSegmentsPage,
    int pageSize = TranscriptExportService.defaultPageSize,
  }) async {
    return file!;
  }
}

class _FakeShareService extends ShareService {
  ShareResultStatus status = ShareResultStatus.success;
  String? lastPath;

  @override
  Future<ShareResultStatus> shareFile({
    required String title,
    required String filePath,
    Rect? sharePositionOrigin,
  }) async {
    lastPath = filePath;
    return status;
  }
}

class _FakeSummaryService extends SessionSummaryService {
  _FakeSummaryService()
      : super(
          databaseService: DatabaseService(),
          llamaService: LlamaService(),
        );

  final queued = <int>[];
  final retried = <int>[];
  final _controller = StreamController<int>.broadcast();

  @override
  Stream<int> get updates => _controller.stream;

  @override
  Future<void> queue(int sessionId, {bool force = false}) async {
    queued.add(sessionId);
  }

  @override
  Future<void> retry(int sessionId) async {
    retried.add(sessionId);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  late _FakeSessionRepository sessions;
  late _FakeSegmentRepository segments;
  late _FakeSummaryService summary;
  late _FakeShareService share;
  late SessionDetailController controller;

  setUp(() async {
    sessions = _FakeSessionRepository(
      const SessionModel(
        id: 7,
        title: 'Detail',
        startedAt: 100,
        endedAt: 200,
        summaryStatus: 'idle',
        createdAt: 100,
      ),
    );
    segments = _FakeSegmentRepository([
      const SegmentModel(
        sessionId: 7,
        startMs: 0,
        endMs: 1000,
        text: 'Hello world',
        createdAt: 1,
      ),
    ]);
    summary = _FakeSummaryService();
    share = _FakeShareService();
    controller = SessionDetailController(
      repository: SessionDetailRepository(
        sessionRepository: sessions,
        segmentRepository: segments,
        transcriptExportService: _FakeExportService(file: File('share.txt')),
      ),
      shareService: share,
      summaryService: summary,
      sessionId: 7,
    );
    Get.put(controller);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await summary.dispose();
    Get.reset();
  });

  test('loadDetail loads session, segments, and queues summary', () async {
    expect(controller.session.value?.id, 7);
    expect(controller.segments, hasLength(1));
    expect(controller.isLoading.value, isFalse);
    expect(summary.queued, contains(7));
    expect(controller.isShowingSummaryLoading, isTrue);
  });

  test('missing session sets errorMessage', () async {
    Get.reset();
    await summary.dispose();
    summary = _FakeSummaryService();
    controller = SessionDetailController(
      repository: SessionDetailRepository(
        sessionRepository: _FakeSessionRepository(null),
        segmentRepository: _FakeSegmentRepository(const []),
        transcriptExportService: _FakeExportService(file: File('x')),
      ),
      shareService: share,
      summaryService: summary,
      sessionId: 99,
    );
    Get.put(controller);
    await Future<void>.delayed(Duration.zero);

    expect(controller.session.value, isNull);
    expect(controller.errorMessage.value, isNotEmpty);
  });

  test('updateTitle optimistically updates and rolls back on failure',
      () async {
    await controller.updateTitle('Renamed');
    expect(controller.session.value?.title, 'Renamed');
    expect(sessions.titleUpdates.single.title, 'Renamed');

    sessions.failTitleUpdate = true;
    await controller.updateTitle('Will Fail');
    expect(controller.session.value?.title, 'Renamed');
  });

  test('retrySummary delegates to summary service', () async {
    await controller.retrySummary();
    expect(summary.retried, [7]);
  });

  test('shareTranscript uses export file and share service', () async {
    await controller.shareTranscript();
    expect(share.lastPath, 'share.txt');
    expect(controller.isSharing.value, isFalse);
  });

  test('loadSegmentsPage paginates until hasMoreSegments is false', () async {
    Get.reset();
    await summary.dispose();
    summary = _FakeSummaryService();
    final many = List.generate(
      25,
      (i) => SegmentModel(
        sessionId: 7,
        startMs: i * 100,
        endMs: i * 100 + 50,
        text: 'line $i',
        createdAt: i,
      ),
    );
    sessions = _FakeSessionRepository(
      const SessionModel(
        id: 7,
        title: 'Detail',
        startedAt: 100,
        endedAt: 200,
        summaryStatus: 'idle',
        createdAt: 100,
      ),
    );
    segments = _FakeSegmentRepository(many);
    share = _FakeShareService();
    controller = SessionDetailController(
      repository: SessionDetailRepository(
        sessionRepository: sessions,
        segmentRepository: segments,
        transcriptExportService: _FakeExportService(file: File('share.txt')),
      ),
      shareService: share,
      summaryService: summary,
      sessionId: 7,
    );
    Get.put(controller);
    await Future<void>.delayed(Duration.zero);

    expect(controller.segments, hasLength(20));
    expect(controller.hasMoreSegments.value, isTrue);

    await controller.loadSegmentsPage();

    expect(controller.segments, hasLength(25));
    expect(controller.hasMoreSegments.value, isFalse);
  });

  test('summary failure getters reflect session status', () {
    controller.session.value = controller.session.value!.copyWith(
      summaryStatus: 'failed_resource',
    );
    expect(controller.isSummaryFailed, isTrue);
    expect(controller.isSummaryFailedResource, isTrue);
    expect(controller.summaryFailureMessage, isNotEmpty);
  });
}
