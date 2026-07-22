import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/service/crash_recovery_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';

class _MarkSavedCall {
  _MarkSavedCall({
    required this.id,
    required this.title,
    required this.endedAt,
    required this.durationSec,
  });

  final int id;
  final String title;
  final int endedAt;
  final int durationSec;
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository(this._unsaved, {this.failMarkIds = const {}});

  final List<SessionModel> _unsaved;
  final Set<int> failMarkIds;
  final List<int> deletedIds = [];
  final List<_MarkSavedCall> markSavedCalls = [];

  @override
  Future<List<SessionModel>> getUnsavedSessions() async => _unsaved;

  @override
  Future<void> deleteSession(int id) async => deletedIds.add(id);

  @override
  Future<void> markSessionSaved({
    required int id,
    required String title,
    required int endedAt,
    required int durationSec,
  }) async {
    if (failMarkIds.contains(id)) {
      throw Exception('simulated failure for session $id');
    }
    markSavedCalls.add(_MarkSavedCall(
      id: id,
      title: title,
      endedAt: endedAt,
      durationSec: durationSec,
    ));
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
  Future<void> finishSession({
    required int id,
    required int endedAt,
    required int durationSec,
  }) =>
      throw UnimplementedError();

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
  Future<int> deleteSessions(List<int> ids) => throw UnimplementedError();

  @override
  Future<void> deleteAllSessions() => throw UnimplementedError();

  @override
  Future<void> updateSummary({required int id, required String summary}) =>
      throw UnimplementedError();

  @override
  Future<void> updateTitle({required int id, required String title}) =>
      throw UnimplementedError();

  @override
  Future<List<SearchResult>> searchSessions(String query, {int limit = 50}) =>
      throw UnimplementedError();
}

class _FakeSegmentRepository implements SegmentRepository {
  _FakeSegmentRepository(this._segmentsBySession);

  final Map<int, List<SegmentModel>> _segmentsBySession;

  @override
  Future<List<SegmentModel>> getSegments(int sessionId) async =>
      _segmentsBySession[sessionId] ?? const [];

  @override
  Future<int> insertSegment(SegmentModel segment) => throw UnimplementedError();

  @override
  Future<void> insertSegments(List<SegmentModel> segments) =>
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

  @override
  Future<int> countDistinctSpeakers(int sessionId) async => 0;
}

SessionModel _draft({required int id, required int startedAt}) {
  return SessionModel(
    id: id,
    title: 'draft',
    startedAt: startedAt,
    isSaved: false,
    createdAt: startedAt,
  );
}

SegmentModel _segment({required int sessionId, required int createdAt}) {
  return SegmentModel(
    sessionId: sessionId,
    startMs: 0,
    endMs: 0,
    text: 'hello',
    createdAt: createdAt,
  );
}

void main() {
  test('finalizes a draft with segments into a saved session', () async {
    final sessionRepo = _FakeSessionRepository([
      _draft(id: 5, startedAt: 1000),
    ]);
    final segmentRepo = _FakeSegmentRepository({
      5: [
        _segment(sessionId: 5, createdAt: 1005),
        _segment(sessionId: 5, createdAt: 1010),
        _segment(sessionId: 5, createdAt: 1008),
      ],
    });
    final service = CrashRecoveryService(
      sessionRepository: sessionRepo,
      segmentRepository: segmentRepo,
    );

    final recovered = await service.recoverUnsavedSessions();

    expect(recovered, 1);
    expect(sessionRepo.markSavedCalls, hasLength(1));
    final call = sessionRepo.markSavedCalls.single;
    expect(call.id, 5);
    expect(call.endedAt, 1010);
    expect(call.durationSec, 10);
    expect(call.title, isNotEmpty);
    expect(sessionRepo.deletedIds, isEmpty);
  });

  test('deletes an empty draft instead of saving it', () async {
    final sessionRepo = _FakeSessionRepository([
      _draft(id: 7, startedAt: 2000),
    ]);
    final segmentRepo = _FakeSegmentRepository({});
    final service = CrashRecoveryService(
      sessionRepository: sessionRepo,
      segmentRepository: segmentRepo,
    );

    final recovered = await service.recoverUnsavedSessions();

    expect(recovered, 0);
    expect(sessionRepo.deletedIds, [7]);
    expect(sessionRepo.markSavedCalls, isEmpty);
  });

  test('recovers each crashed draft as its own session', () async {
    final sessionRepo = _FakeSessionRepository([
      _draft(id: 1, startedAt: 1000),
      _draft(id: 2, startedAt: 3000),
    ]);
    final segmentRepo = _FakeSegmentRepository({
      1: [_segment(sessionId: 1, createdAt: 1020)],
      2: [_segment(sessionId: 2, createdAt: 3030)],
    });
    final service = CrashRecoveryService(
      sessionRepository: sessionRepo,
      segmentRepository: segmentRepo,
    );

    final recovered = await service.recoverUnsavedSessions();

    expect(recovered, 2);
    expect(sessionRepo.markSavedCalls.map((c) => c.id), [1, 2]);
    expect(sessionRepo.markSavedCalls.map((c) => c.durationSec), [20, 30]);
  });

  test('does nothing when there are no drafts', () async {
    final sessionRepo = _FakeSessionRepository([]);
    final segmentRepo = _FakeSegmentRepository({});
    final service = CrashRecoveryService(
      sessionRepository: sessionRepo,
      segmentRepository: segmentRepo,
    );

    final recovered = await service.recoverUnsavedSessions();

    expect(recovered, 0);
    expect(sessionRepo.markSavedCalls, isEmpty);
    expect(sessionRepo.deletedIds, isEmpty);
  });

  test('keeps recovering remaining drafts when one fails', () async {
    final sessionRepo = _FakeSessionRepository(
      [
        _draft(id: 1, startedAt: 1000),
        _draft(id: 2, startedAt: 2000),
      ],
      failMarkIds: {1},
    );
    final segmentRepo = _FakeSegmentRepository({
      1: [_segment(sessionId: 1, createdAt: 1010)],
      2: [_segment(sessionId: 2, createdAt: 2010)],
    });
    final service = CrashRecoveryService(
      sessionRepository: sessionRepo,
      segmentRepository: segmentRepo,
    );

    final recovered = await service.recoverUnsavedSessions();

    expect(recovered, 1);
    expect(sessionRepo.markSavedCalls.map((c) => c.id), [2]);
  });
}
