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
import 'package:transcribe_summarize_clearhear/screen/session_details/session_detail_view.dart';
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

  @override
  Future<SessionModel?> getSession(int id) async =>
      session?.id == id ? session : null;

  @override
  Future<void> updateTitle({required int id, required String title}) async {
    session = session?.copyWith(title: title);
  }

  @override
  Future<void> deleteSession(int id) async {
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
  @override
  Future<File> exportTextFile({
    required SessionModel session,
    required SegmentPageLoader loadSegmentsPage,
    int pageSize = TranscriptExportService.defaultPageSize,
  }) async {
    return File('share.txt');
  }
}

class _FakeShareService extends ShareService {
  @override
  Future<ShareResultStatus> shareFile({
    required String title,
    required String filePath,
    Rect? sharePositionOrigin,
  }) async {
    return ShareResultStatus.success;
  }
}

class _FakeSummaryService extends SessionSummaryService {
  _FakeSummaryService()
      : super(
          databaseService: DatabaseService(),
          llamaService: LlamaService(),
        );

  final _controller = StreamController<int>.broadcast();

  @override
  Stream<int> get updates => _controller.stream;

  @override
  Future<void> queue(int sessionId, {bool force = false}) async {}

  @override
  Future<void> retry(int sessionId) async {}

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

  late _FakeSummaryService summary;

  tearDown(() async {
    await summary.dispose();
    Get.reset();
  });

  testWidgets('shows session title, summary, and transcript', (tester) async {
    summary = _FakeSummaryService();
    final controller = SessionDetailController(
      repository: SessionDetailRepository(
        sessionRepository: _FakeSessionRepository(
          const SessionModel(
            id: 7,
            title: 'Design sync',
            startedAt: 1700000000,
            endedAt: 1700000600,
            durationSec: 600,
            summary: 'Discussed layout options.',
            summaryStatus: 'ready',
            createdAt: 1700000000,
            isSaved: true,
          ),
        ),
        segmentRepository: _FakeSegmentRepository([
          const SegmentModel(
            sessionId: 7,
            startMs: 0,
            endMs: 1500,
            text: 'Hello from transcript',
            speakerLabel: 'Speaker 1',
            createdAt: 1,
          ),
        ]),
        transcriptExportService: _FakeExportService(),
      ),
      shareService: _FakeShareService(),
      summaryService: summary,
      sessionId: 7,
    );
    Get.put(controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const SessionDetailView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Design sync'), findsOneWidget);
    expect(find.text('Discussed layout options.'), findsOneWidget);
    expect(find.text('Hello from transcript'), findsOneWidget);
    expect(find.text('Share text'), findsOneWidget);
  });
}
