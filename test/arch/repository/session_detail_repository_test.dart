import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_detail_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/service/transcript_export_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    this.session,
    this.throwOnGet = false,
    this.throwOnDelete = false,
    this.throwOnUpdateTitle = false,
  });

  SessionModel? session;
  final bool throwOnGet;
  final bool throwOnDelete;
  final bool throwOnUpdateTitle;
  final List<({int id, String title})> titleUpdates = [];
  final List<int> deletedIds = [];

  @override
  Future<SessionModel?> getSession(int id) async {
    if (throwOnGet) throw Exception('get failed');
    return session?.id == id ? session : null;
  }

  @override
  Future<void> deleteSession(int id) async {
    if (throwOnDelete) throw Exception('delete failed');
    deletedIds.add(id);
  }

  @override
  Future<void> updateTitle({required int id, required String title}) async {
    if (throwOnUpdateTitle) throw Exception('title failed');
    titleUpdates.add((id: id, title: title));
  }

  @override
  Future<int> createSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) =>
      throw UnimplementedError();

  @override
  Future<int> createDraftSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markSessionSaved({
    required int id,
    required String title,
    required int endedAt,
    required int durationSec,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> finishSession({
    required int id,
    required int endedAt,
    required int durationSec,
  }) =>
      throw UnimplementedError();

  @override
  Future<int> deleteSessions(List<int> ids) => throw UnimplementedError();

  @override
  Future<void> deleteAllSessions() => throw UnimplementedError();

  @override
  Future<List<SessionModel>> getUnsavedSessions() => throw UnimplementedError();

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
}

class _FakeSegmentRepository implements SegmentRepository {
  _FakeSegmentRepository({
    this.segments = const [],
    this.throwOnGet = false,
    this.throwOnPaged = false,
  });

  final List<SegmentModel> segments;
  final bool throwOnGet;
  final bool throwOnPaged;
  final List<({int sessionId, int offset, int limit})> pagedCalls = [];

  @override
  Future<List<SegmentModel>> getSegments(int sessionId) async {
    if (throwOnGet) throw Exception('segments failed');
    return segments.where((s) => s.sessionId == sessionId).toList();
  }

  @override
  Future<List<SegmentModel>> getSegmentsPaged({
    required int sessionId,
    required int offset,
    required int limit,
  }) async {
    pagedCalls.add((sessionId: sessionId, offset: offset, limit: limit));
    if (throwOnPaged) throw Exception('paged failed');
    return segments
        .where((s) => s.sessionId == sessionId)
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<int> insertSegment(SegmentModel segment) => throw UnimplementedError();

  @override
  Future<void> insertSegments(List<SegmentModel> segments) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSegments(int sessionId) => throw UnimplementedError();

  @override
  Future<int> countDistinctSpeakers(int sessionId) async => 0;
}

class _FakeExportService extends TranscriptExportService {
  _FakeExportService({this.file, this.error});

  final File? file;
  final Object? error;
  SessionModel? lastSession;
  SegmentPageLoader? lastLoader;

  @override
  Future<File> exportTextFile({
    required SessionModel session,
    required SegmentPageLoader loadSegmentsPage,
    int pageSize = TranscriptExportService.defaultPageSize,
  }) async {
    lastSession = session;
    lastLoader = loadSegmentsPage;
    if (error != null) throw error!;
    return file!;
  }
}

SegmentModel _segment(int id, int sessionId, String text) {
  return SegmentModel(
    id: id,
    sessionId: sessionId,
    text: text,
    startMs: 0,
    endMs: 1000,
    createdAt: 1,
  );
}

void main() {
  const session = SessionModel(
    id: 5,
    title: 'Detail',
    startedAt: 100,
    createdAt: 100,
  );

  test('fetchSession returns session and swallows errors as null', () async {
    final ok = SessionDetailRepository(
      sessionRepository: _FakeSessionRepository(session: session),
      segmentRepository: _FakeSegmentRepository(),
      transcriptExportService: _FakeExportService(file: File('x')),
    );
    final failing = SessionDetailRepository(
      sessionRepository: _FakeSessionRepository(throwOnGet: true),
      segmentRepository: _FakeSegmentRepository(),
      transcriptExportService: _FakeExportService(file: File('x')),
    );

    expect(await ok.fetchSession(5), session);
    expect(await ok.fetchSession(99), isNull);
    expect(await failing.fetchSession(5), isNull);
  });

  test('fetchSegments / fetchSegmentsPaged return data or empty on error',
      () async {
    final segments = [
      _segment(1, 5, 'a'),
      _segment(2, 5, 'b'),
    ];
    final repo = SessionDetailRepository(
      sessionRepository: _FakeSessionRepository(session: session),
      segmentRepository: _FakeSegmentRepository(segments: segments),
      transcriptExportService: _FakeExportService(file: File('x')),
    );
    final failing = SessionDetailRepository(
      sessionRepository: _FakeSessionRepository(session: session),
      segmentRepository: _FakeSegmentRepository(
        throwOnGet: true,
        throwOnPaged: true,
      ),
      transcriptExportService: _FakeExportService(file: File('x')),
    );

    expect(await repo.fetchSegments(5), hasLength(2));
    expect(
      await repo.fetchSegmentsPaged(5, offset: 1, limit: 1),
      [segments[1]],
    );
    expect(await failing.fetchSegments(5), isEmpty);
    expect(await failing.fetchSegmentsPaged(5, offset: 0, limit: 10), isEmpty);
  });

  test('deleteSession and updateSessionTitle report success/failure', () async {
    final sessions = _FakeSessionRepository(session: session);
    final repo = SessionDetailRepository(
      sessionRepository: sessions,
      segmentRepository: _FakeSegmentRepository(),
      transcriptExportService: _FakeExportService(file: File('x')),
    );
    final failing = SessionDetailRepository(
      sessionRepository: _FakeSessionRepository(
        throwOnDelete: true,
        throwOnUpdateTitle: true,
      ),
      segmentRepository: _FakeSegmentRepository(),
      transcriptExportService: _FakeExportService(file: File('x')),
    );

    expect(await repo.deleteSession(5), isTrue);
    expect(sessions.deletedIds, [5]);
    expect(await repo.updateSessionTitle(sessionId: 5, title: 'New'), isTrue);
    expect(sessions.titleUpdates.single.title, 'New');
    expect(await failing.deleteSession(5), isFalse);
    expect(
      await failing.updateSessionTitle(sessionId: 5, title: 'X'),
      isFalse,
    );
  });

  test('exportTranscriptFile requires id and wires paged loader', () async {
    final export = _FakeExportService(file: File('export.txt'));
    final segments = _FakeSegmentRepository(segments: [_segment(1, 5, 'hi')]);
    final repo = SessionDetailRepository(
      sessionRepository: _FakeSessionRepository(session: session),
      segmentRepository: segments,
      transcriptExportService: export,
    );

    expect(
      await repo.exportTranscriptFile(
        const SessionModel(
          title: 'No id',
          startedAt: 1,
          createdAt: 1,
        ),
      ),
      isNull,
    );

    final file = await repo.exportTranscriptFile(session);
    expect(file?.path, 'export.txt');
    expect(export.lastSession, session);

    final page = await export.lastLoader!(offset: 0, limit: 10);
    expect(page.single.text, 'hi');
    expect(segments.pagedCalls.single.sessionId, 5);
  });

  test('exportTranscriptFile returns null when export throws', () async {
    final repo = SessionDetailRepository(
      sessionRepository: _FakeSessionRepository(session: session),
      segmentRepository: _FakeSegmentRepository(),
      transcriptExportService: _FakeExportService(error: Exception('boom')),
    );

    expect(await repo.exportTranscriptFile(session), isNull);
  });
}
