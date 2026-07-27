import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';

class _FakeSegmentRepository implements SegmentRepository {
  _FakeSegmentRepository({this.speakerCounts = const {}});

  final Map<int, int> speakerCounts;

  @override
  Future<int> countDistinctSpeakers(int sessionId) async =>
      speakerCounts[sessionId] ?? 0;

  @override
  Future<void> deleteSegments(int sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<SegmentModel>> getSegments(int sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<SegmentModel>> getSegmentsPaged({
    required int sessionId,
    required int offset,
    required int limit,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> insertSegment(SegmentModel segment) {
    throw UnimplementedError();
  }

  @override
  Future<void> insertSegments(List<SegmentModel> segments) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    this.session,
    this.sessions = const [],
    this.hasMore = false,
    this.searchResults = const [],
    this.deleteCount,
    this.fetchThrows = false,
    this.searchThrows = false,
  });

  final SessionModel? session;
  final List<SessionModel> sessions;
  final bool hasMore;
  final List<SearchResult> searchResults;
  final int? deleteCount;
  final bool fetchThrows;
  final bool searchThrows;
  final List<List<int>> deletedBatches = [];
  final List<({int id, String title})> titleUpdates = [];
  bool? lastSavedOnly;

  @override
  Future<int> createSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(int id) {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteSessions(List<int> ids) async {
    deletedBatches.add(ids);
    return deleteCount ?? ids.length;
  }

  @override
  Future<void> deleteAllSessions() {
    throw UnimplementedError();
  }

  @override
  Future<void> finishSession({
    required int id,
    required int endedAt,
    required int durationSec,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> createDraftSession({
    required String title,
    required int startedAt,
    String language = 'auto',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<SessionModel>> getUnsavedSessions() {
    throw UnimplementedError();
  }

  @override
  Future<void> markSessionSaved({
    required int id,
    required String title,
    required int endedAt,
    required int durationSec,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<SearchResult>> searchSessions(String query, {int limit = 50}) async {
    if (searchThrows) throw Exception('search failed');
    return searchResults;
  }

  @override
  Future<SessionPageResult> getAllSessions({
    required int offset,
    required int limit,
    bool savedOnly = false,
  }) async {
    if (fetchThrows) throw Exception('fetch failed');
    lastSavedOnly = savedOnly;
    final page = sessions.skip(offset).take(limit).toList();
    return SessionPageResult(items: page, hasMore: hasMore);
  }

  @override
  Future<SessionModel?> getSession(int id) async =>
      session?.id == id ? session : null;

  @override
  Future<void> updateSummary({required int id, required String summary}) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTitle({required int id, required String title}) async {
    titleUpdates.add((id: id, title: title));
  }
}

void main() {
  const readySession = SessionModel(
    id: 1,
    title: 'Session',
    startedAt: 1700000000,
    endedAt: 1700000120,
    durationSec: 120,
    summary: 'First line\nSecond line\nThird line',
    summaryStatus: 'ready',
    createdAt: 1700000000,
  );

  HistoryRepository buildRepo({
    SessionModel? session,
    List<SessionModel> sessions = const [],
    bool hasMore = false,
    List<SearchResult> searchResults = const [],
    Map<int, int> speakerCounts = const {},
    int? deleteCount,
    bool fetchThrows = false,
    bool searchThrows = false,
  }) {
    return HistoryRepository(
      sessionRepository: _FakeSessionRepository(
        session: session,
        sessions: sessions,
        hasMore: hasMore,
        searchResults: searchResults,
        deleteCount: deleteCount,
        fetchThrows: fetchThrows,
        searchThrows: searchThrows,
      ),
      segmentRepository: _FakeSegmentRepository(speakerCounts: speakerCounts),
    );
  }

  test('HistoryRepository exposes first two summary lines for history preview',
      () async {
    final repository = buildRepo(session: readySession);

    final item = await repository.getSession('1');

    expect(item?.snippet, 'First line\nSecond line');
    expect(item?.summaryStatus, 'ready');
    expect(item?.duration, 120);
    expect(
      item?.timestamp,
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    );
  });

  test('HistoryRepository uses distinct speaker count when available',
      () async {
    final repository = buildRepo(
      session: readySession,
      speakerCounts: const {1: 3},
    );

    final item = await repository.getSession('1');
    expect(item?.speakerCount, 3);
  });

  test('HistoryRepository defaults speakerCount to 1 when none labeled',
      () async {
    final repository = buildRepo(session: readySession);
    final item = await repository.getSession('1');
    expect(item?.speakerCount, 1);
  });

  test('HistoryRepository shows the generating placeholder while queued',
      () async {
    final repository = buildRepo(
      session: const SessionModel(
        id: 1,
        title: 'Session',
        startedAt: 1,
        endedAt: 2,
        durationSec: 120,
        summaryStatus: 'processing',
        createdAt: 1,
      ),
    );

    final item = await repository.getSession('1');

    expect(item?.snippet, '[Generating summary...]');
    expect(item?.summaryStatus, 'processing');
  });

  test('HistoryRepository shows generating placeholder for idle ended session',
      () async {
    final repository = buildRepo(
      session: const SessionModel(
        id: 1,
        title: 'Session',
        startedAt: 1,
        endedAt: 2,
        durationSec: 120,
        summaryStatus: 'idle',
        createdAt: 1,
      ),
    );

    final item = await repository.getSession('1');
    expect(item?.snippet, '[Generating summary...]');
  });

  test('HistoryRepository shows failure snippet for failed summaries',
      () async {
    final repository = buildRepo(
      session: const SessionModel(
        id: 1,
        title: 'Session',
        startedAt: 1,
        endedAt: 2,
        durationSec: 120,
        summaryStatus: 'failed',
        createdAt: 1,
      ),
    );

    final item = await repository.getSession('1');

    expect(item?.snippet, 'Summary generation failed.');
  });

  test('HistoryRepository shows resource-limit failure snippet', () async {
    final repository = buildRepo(
      session: const SessionModel(
        id: 1,
        title: 'Session',
        startedAt: 1,
        endedAt: 2,
        durationSec: 120,
        summaryStatus: 'failed_resource',
        createdAt: 1,
      ),
    );

    final item = await repository.getSession('1');

    expect(
      item?.snippet,
      'Summary generation failed due to system resource limits.',
    );
  });

  test('HistoryRepository returns null for non-numeric session ids', () async {
    final repository = buildRepo();
    expect(await repository.getSession('abc'), isNull);
  });

  test('HistoryRepository.updateSessionTitle rejects invalid ids', () async {
    final repository = buildRepo();
    expect(await repository.updateSessionTitle('abc', 'New'), isFalse);
  });

  test('HistoryRepository.updateSessionTitle delegates valid ids', () async {
    final sessions = _FakeSessionRepository(session: readySession);
    final repository = HistoryRepository(
      sessionRepository: sessions,
      segmentRepository: _FakeSegmentRepository(),
    );

    expect(await repository.updateSessionTitle('1', 'Renamed'), isTrue);
    expect(sessions.titleUpdates.single.title, 'Renamed');
  });

  test('fetchSessions maps saved sessions and requests savedOnly', () async {
    final sessions = _FakeSessionRepository(
      sessions: [readySession],
      hasMore: true,
    );
    final repository = HistoryRepository(
      sessionRepository: sessions,
      segmentRepository: _FakeSegmentRepository(),
    );

    final page = await repository.fetchSessions(offset: 0, limit: 20);

    expect(page.items, hasLength(1));
    expect(page.items.single.id, '1');
    expect(page.hasMore, isTrue);
    expect(sessions.lastSavedOnly, isTrue);
  });

  test('fetchSessions returns empty page when underlying fetch fails',
      () async {
    final repository = buildRepo(fetchThrows: true);
    final page = await repository.fetchSessions(offset: 0, limit: 20);
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('deleteSessions maps string ids and returns count', () async {
    final sessions = _FakeSessionRepository();
    final repository = HistoryRepository(
      sessionRepository: sessions,
      segmentRepository: _FakeSegmentRepository(),
    );

    expect(await repository.deleteSessions(['1', '2']), 2);
    expect(sessions.deletedBatches.single, [1, 2]);
    expect(await repository.deleteSessions([]), 0);
  });

  test('deleteSessions returns 0 for non-numeric ids', () async {
    final repository = buildRepo();
    expect(await repository.deleteSessions(['abc']), 0);
  });

  test('searchSessions maps SearchResult into HistorySearchHit', () async {
    final repository = buildRepo(
      searchResults: [
        const SearchResult(
          session: readySession,
          titleMatched: true,
          summaryMatched: false,
          transcriptMatched: true,
        ),
      ],
    );

    final hits = await repository.searchSessions('stand');

    expect(hits, hasLength(1));
    expect(hits.single.item.id, '1');
    expect(hits.single.titleMatched, isTrue);
    expect(hits.single.summaryMatched, isFalse);
    expect(hits.single.transcriptMatched, isTrue);
  });

  test('searchSessions returns empty list on failure', () async {
    final repository = buildRepo(searchThrows: true);
    expect(await repository.searchSessions('q'), isEmpty);
  });
}
