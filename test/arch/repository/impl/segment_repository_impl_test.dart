import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';

import '../../../helpers/test_database.dart';

void main() {
  late TestDatabaseHarness harness;
  late SessionRepositoryImpl sessions;
  late SegmentRepositoryImpl segments;
  late int sessionId;

  setUp(() async {
    harness = await TestDatabaseHarness.create();
    sessions = SessionRepositoryImpl(harness.databaseService);
    segments = SegmentRepositoryImpl(harness.databaseService);
    sessionId = await sessions.createSession(title: 'Seg', startedAt: 1);
  });

  tearDown(() async {
    await harness.dispose();
  });

  test('insertSegment and getSegments order by start_ms', () async {
    await segments.insertSegment(
      SegmentModel(
        sessionId: sessionId,
        startMs: 2000,
        endMs: 3000,
        text: 'second',
        createdAt: 2,
      ),
    );
    await segments.insertSegment(
      SegmentModel(
        sessionId: sessionId,
        startMs: 0,
        endMs: 1000,
        text: 'first',
        createdAt: 1,
      ),
    );

    final rows = await segments.getSegments(sessionId);
    expect(rows.map((s) => s.text), ['first', 'second']);
  });

  test('insertSegments batch and getSegmentsPaged', () async {
    await segments.insertSegments([
      for (var i = 0; i < 5; i++)
        SegmentModel(
          sessionId: sessionId,
          startMs: i * 1000,
          endMs: (i + 1) * 1000,
          text: 'line $i',
          createdAt: i,
        ),
    ]);

    final page = await segments.getSegmentsPaged(
      sessionId: sessionId,
      offset: 2,
      limit: 2,
    );
    expect(page.map((s) => s.text), ['line 2', 'line 3']);
  });

  test('countDistinctSpeakers ignores null labels', () async {
    await segments.insertSegments([
      SegmentModel(
        sessionId: sessionId,
        startMs: 0,
        endMs: 100,
        text: 'a',
        speakerLabel: 'Speaker 1',
        createdAt: 1,
      ),
      SegmentModel(
        sessionId: sessionId,
        startMs: 100,
        endMs: 200,
        text: 'b',
        speakerLabel: 'Speaker 2',
        createdAt: 2,
      ),
      SegmentModel(
        sessionId: sessionId,
        startMs: 200,
        endMs: 300,
        text: 'c',
        speakerLabel: 'Speaker 1',
        createdAt: 3,
      ),
      SegmentModel(
        sessionId: sessionId,
        startMs: 300,
        endMs: 400,
        text: 'd',
        createdAt: 4,
      ),
    ]);

    expect(await segments.countDistinctSpeakers(sessionId), 2);
  });

  test('deleteSegments removes all rows for session', () async {
    await segments.insertSegment(
      SegmentModel(
        sessionId: sessionId,
        startMs: 0,
        endMs: 100,
        text: 'delete',
        createdAt: 1,
      ),
    );
    final otherSessionId = await sessions.createSession(title: 'Other', startedAt: 2);
    await segments.insertSegment(
      SegmentModel(
        sessionId: otherSessionId,
        startMs: 0,
        endMs: 100,
        text: 'keep',
        createdAt: 1,
      ),
    );
    await segments.deleteSegments(sessionId);
    expect(await segments.getSegments(sessionId), isEmpty);
    expect(
      (await segments.getSegments(otherSessionId)).map((s) => s.text),
      ['keep'],
    );
  });
}
