import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/models/search_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';

void main() {
  const session = SessionModel(
    id: 1,
    title: 'Search hit',
    startedAt: 1,
    createdAt: 1,
  );

  group('SearchResult.fromMap', () {
    test('treats 1 as matched flags', () {
      final result = SearchResult.fromMap({
        'title_matched': 1,
        'summary_matched': 1,
        'transcript_matched': 1,
      }, session);

      expect(result.titleMatched, isTrue);
      expect(result.summaryMatched, isTrue);
      expect(result.transcriptMatched, isTrue);
      expect(result.session, session);
    });

    test('treats 0 and null as unmatched', () {
      final result = SearchResult.fromMap({
        'title_matched': 0,
        'summary_matched': null,
      }, session);

      expect(result.titleMatched, isFalse);
      expect(result.summaryMatched, isFalse);
      expect(result.transcriptMatched, isFalse);
    });
  });
}
