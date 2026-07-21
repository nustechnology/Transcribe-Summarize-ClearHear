import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_page_result.dart';

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository(this.session);

  final SessionModel? session;

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
  Future<int> deleteSessions(List<int> ids) {
    throw UnimplementedError();
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
  Future<List<SearchResult>> searchSessions(String query, {int limit = 50}) {
    throw UnimplementedError();
  }

  @override
  Future<SessionPageResult> getAllSessions({
    required int offset,
    required int limit,
    bool savedOnly = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionModel?> getSession(int id) async => session;

  @override
  Future<void> updateSummary({required int id, required String summary}) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTitle({required int id, required String title}) {
    throw UnimplementedError();
  }
}

void main() {
  test('HistoryRepository exposes first two summary lines for history preview',
      () async {
    final repository = HistoryRepository(
      sessionRepository: _FakeSessionRepository(
        const SessionModel(
          id: 1,
          title: 'Session',
          startedAt: 1,
          endedAt: 2,
          durationSec: 120,
          summary: 'First line\nSecond line\nThird line',
          summaryStatus: 'ready',
          createdAt: 1,
        ),
      ),
    );

    final item = await repository.getSession('1');

    expect(item?.snippet, 'First line\nSecond line');
    expect(item?.summaryStatus, 'ready');
  });

  test('HistoryRepository shows the generating placeholder while queued',
      () async {
    final repository = HistoryRepository(
      sessionRepository: _FakeSessionRepository(
        const SessionModel(
          id: 1,
          title: 'Session',
          startedAt: 1,
          endedAt: 2,
          durationSec: 120,
          summaryStatus: 'processing',
          createdAt: 1,
        ),
      ),
    );

    final item = await repository.getSession('1');

    expect(item?.snippet, '[Generating summary...]');
    expect(item?.summaryStatus, 'processing');
  });
}
