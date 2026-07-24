import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';

void main() {
  const session = SessionModel(
    id: 3,
    title: 'Standup',
    startedAt: 1700000000,
    endedAt: 1700000120,
    durationSec: 120,
    isSaved: true,
    summary: 'Discussed blockers',
    summaryStatus: 'ready',
    language: 'en',
    createdAt: 1700000000,
  );

  group('SessionModel map round-trip', () {
    test('toMap / fromMap preserve fields', () {
      final restored = SessionModel.fromMap(session.toMap());

      expect(restored.id, session.id);
      expect(restored.title, session.title);
      expect(restored.startedAt, session.startedAt);
      expect(restored.endedAt, session.endedAt);
      expect(restored.durationSec, session.durationSec);
      expect(restored.isSaved, isTrue);
      expect(restored.summary, session.summary);
      expect(restored.summaryStatus, 'ready');
      expect(restored.language, 'en');
      expect(restored.createdAt, session.createdAt);
    });

    test('fromMap defaults missing optional fields', () {
      final restored = SessionModel.fromMap({
        'title': null,
        'started_at': 1,
        'created_at': 2,
      });

      expect(restored.title, 'Untitled');
      expect(restored.isSaved, isTrue);
      expect(restored.summaryStatus, 'idle');
      expect(restored.language, 'auto');
      expect(restored.id, isNull);
    });
  });

  group('SessionModel status helpers', () {
    test('hasSummary requires ready status and non-empty text', () {
      expect(session.hasSummary, isTrue);
      expect(
        session.copyWith(summaryStatus: 'processing').hasSummary,
        isFalse,
      );
      expect(session.copyWith(summary: '  ').hasSummary, isFalse);
    });

    test('isSummaryProcessing covers queued and processing', () {
      expect(session.copyWith(summaryStatus: 'queued').isSummaryProcessing,
          isTrue);
      expect(
        session.copyWith(summaryStatus: 'processing').isSummaryProcessing,
        isTrue,
      );
      expect(session.isSummaryProcessing, isFalse);
    });

    test('hasSummaryFailed matches failed* statuses', () {
      expect(
        session.copyWith(summaryStatus: 'failed').hasSummaryFailed,
        isTrue,
      );
      expect(
        session.copyWith(summaryStatus: 'failed_resource').hasSummaryFailed,
        isTrue,
      );
      expect(session.hasSummaryFailed, isFalse);
    });
  });

  test('copyWith overrides selected fields only', () {
    final updated = session.copyWith(title: 'Retro', isSaved: false);
    expect(updated.title, 'Retro');
    expect(updated.isSaved, isFalse);
    expect(updated.id, session.id);
    expect(updated.summary, session.summary);
  });
}
