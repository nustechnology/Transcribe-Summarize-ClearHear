import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';

import '../../../helpers/test_database.dart';

void main() {
  late TestDatabaseHarness harness;
  late SessionRepositoryImpl sessions;
  late SegmentRepositoryImpl segments;

  setUp(() async {
    harness = await TestDatabaseHarness.create();
    sessions = SessionRepositoryImpl(harness.databaseService);
    segments = SegmentRepositoryImpl(harness.databaseService);
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('createDraftSession is unsaved until markSessionSaved', () async {
    final id = await sessions.createDraftSession(
      title: 'Draft',
      startedAt: 100,
    );
    final draft = await sessions.getSession(id);
    expect(draft?.isSaved, isFalse);

    await sessions.markSessionSaved(
      id: id,
      title: 'Saved Draft',
      endedAt: 200,
      durationSec: 100,
    );
    final saved = await sessions.getSession(id);
    expect(saved?.isSaved, isTrue);
    expect(saved?.title, 'Saved Draft');
    expect(saved?.durationSec, 100);
  });

  test('getAllSessions respects savedOnly and pagination hasMore', () async {
    await sessions.createSession(title: 'A', startedAt: 10);
    await sessions.createDraftSession(title: 'Draft', startedAt: 20);
    await sessions.createSession(title: 'B', startedAt: 30);

    final savedOnly = await sessions.getAllSessions(
      offset: 0,
      limit: 10,
      savedOnly: true,
    );
    expect(savedOnly.items.map((s) => s.title), ['B', 'A']);

    final page = await sessions.getAllSessions(offset: 0, limit: 1);
    expect(page.items, hasLength(1));
    expect(page.hasMore, isTrue);
  });

  test('deleteSession cascades segments', () async {
    final id = await sessions.createSession(title: 'Del', startedAt: 1);
    await segments.insertSegment(
      SegmentModel(
        sessionId: id,
        startMs: 0,
        endMs: 100,
        text: 'gone',
        createdAt: 1,
      ),
    );
    final otherId = await sessions.createSession(title: 'Keep', startedAt: 2);
    await segments.insertSegment(
      SegmentModel(
        sessionId: otherId,
        startMs: 0,
        endMs: 100,
        text: 'retained',
        createdAt: 2,
      ),
    );

    await sessions.deleteSession(id);
    expect(await sessions.getSession(id), isNull);
    expect(await segments.getSegments(id), isEmpty);
    expect(
      (await segments.getSegments(otherId)).map((segment) => segment.text),
      ['retained'],
    );
  });

  test('searchSessions matches title and transcript via FTS', () async {
    final id = await sessions.createSession(
      title: 'Standup notes',
      startedAt: 50,
    );
    await segments.insertSegment(
      SegmentModel(
        sessionId: id,
        startMs: 0,
        endMs: 1000,
        text: 'discussed blockers yesterday',
        createdAt: 1,
      ),
    );

    final byTitle = await sessions.searchSessions('Standup');
    expect(byTitle, hasLength(1));
    expect(byTitle.single.titleMatched, isTrue);

    final byTranscript = await sessions.searchSessions('blockers');
    expect(byTranscript, hasLength(1));
    expect(byTranscript.single.transcriptMatched, isTrue);
  });

  test('getUnsavedSessions returns only drafts', () async {
    await sessions.createSession(title: 'Saved', startedAt: 1);
    final draftId =
        await sessions.createDraftSession(title: 'Unsaved', startedAt: 2);

    final unsaved = await sessions.getUnsavedSessions();
    expect(unsaved.map((s) => s.id), [draftId]);
  });

  test('updateSummary and updateTitle persist fields', () async {
    final id = await sessions.createSession(title: 'Original', startedAt: 10);

    await sessions.updateTitle(id: id, title: 'Renamed');
    await sessions.updateSummary(id: id, summary: 'Short summary');

    final updated = await sessions.getSession(id);
    expect(updated?.title, 'Renamed');
    expect(updated?.summary, 'Short summary');
  });

  test('deleteSessions and deleteAllSessions remove rows', () async {
    final a = await sessions.createSession(title: 'A', startedAt: 1);
    final b = await sessions.createSession(title: 'B', startedAt: 2);
    await sessions.createSession(title: 'C', startedAt: 3);

    expect(await sessions.deleteSessions([a, b]), 2);
    expect(await sessions.getSession(a), isNull);
    expect(await sessions.getSession(b), isNull);

    await sessions.deleteAllSessions();
    final remaining = await sessions.getAllSessions(offset: 0, limit: 10);
    expect(remaining.items, isEmpty);
  });

  test('searchSessions treats percent literally via LIKE escape', () async {
    final id = await sessions.createSession(title: '100% done', startedAt: 1);
    final wildcardOnlyId = await sessions.createSession(title: '1000% done', startedAt: 2);

    final hits = await sessions.searchSessions('100%');
    expect(hits.map((h) => h.session.id), contains(id));
    expect(hits.map((h) => h.session.id), isNot(contains(wildcardOnlyId)));
  });
}
