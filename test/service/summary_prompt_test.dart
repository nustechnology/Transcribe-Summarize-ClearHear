import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe_summarize_clearhear/config/ml_model_config.dart';
import 'package:transcribe_summarize_clearhear/service/summary_prompt.dart';

void main() {
  test('clipTranscriptForSummary leaves short transcripts unchanged', () {
    const transcript = 'one line\nsecond line';

    expect(
      clipTranscriptForSummary(transcript, maxChars: 200),
      equals(transcript),
    );
  });

  test('clipTranscriptForSummary preserves head and tail when trimming', () {
    final transcript = List.generate(400, (i) => 'word$i').join(' ');

    final clipped = clipTranscriptForSummary(transcript, maxChars: 160);

    expect(clipped.length, lessThanOrEqualTo(160));
    expect(clipped, contains('word0'));
    expect(clipped, contains('word399'));
    expect(clipped, contains('transcript truncated for model context'));
  });

  test('buildSummaryPrompt includes the clipped transcript', () {
    final prompt = buildSummaryPrompt(
      'alpha beta gamma delta epsilon zeta eta theta',
      maxTranscriptChars: 50,
    );

    expect(prompt, contains('Summarize this transcript:'));
    expect(prompt, contains('alpha beta gamma'));
    expect(prompt, contains('<|im_start|> assistant'));
  });

  test('buildSummaryPrompt forbids section labels and markdown', () {
    final prompt = buildSummaryPrompt('some transcript text');

    expect(prompt, contains('No section labels'));
    expect(prompt, contains('No markdown'));
    expect(prompt, isNot(contains('Always answer using exactly these four')));
  });

  test('buildBoundedSummaryPrompt stays within batch/context budget', () {
    final transcript = List.generate(2000, (i) => 'word$i').join(' ');
    final maxPromptTokens = [
      MlModelConfig.summaryBatchSize - 16,
      MlModelConfig.summaryContextSize -
          MlModelConfig.summaryMaxTokens -
          32,
    ].reduce((left, right) => left < right ? left : right);

    final prompt = buildBoundedSummaryPrompt(transcript);

    expect(prompt, contains('Summarize this transcript:'));
    expect(estimatePromptTokens(prompt), lessThanOrEqualTo(maxPromptTokens));
  });
}
