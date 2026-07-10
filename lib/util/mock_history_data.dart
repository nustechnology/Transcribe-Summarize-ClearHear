abstract final class MockHistoryData {
  /// Flip on in debug builds to seed a session for AI summary testing.
  static const enabled = false;

  /// Target word count for the mock transcript (~1600 words).
  static const transcriptWordCount = 1600;

  /// Unique title so re-runs do not duplicate the mock session.
  static const title =
      '[Mock] Long transcript (1600 words) — AI summary test';

  /// Leave empty to force on-device summary generation in session detail.
  static const summaryText = '';

  static List<String> get transcriptSegments => buildTranscriptSegments(
        wordCount: transcriptWordCount,
      );

  /// Builds a realistic meeting transcript split into ASR-like segments.
  static List<String> buildTranscriptSegments({int wordCount = 1600}) {
    const snippets = [
      'Good morning everyone. Thanks for joining the extended product review.',
      'Alice reported that the payment gateway integration is progressing but blocked on sandbox credentials from the vendor.',
      'Bob mentioned that several enterprise customers reported intermittent failures when completing credit card transactions during peak traffic hours.',
      'After reviewing the logs, the engineering team believes the problem may be related to duplicated API requests during network retries.',
      'Carol suggested we add idempotency keys to every checkout request and tighten retry backoff on the mobile client.',
      'The monitoring dashboard shows a noticeable increase in failed payment attempts between six and nine in the morning Pacific time.',
      'David proposed a short-term mitigation by routing ten percent of traffic to the secondary payment processor while we investigate.',
      'Eve reminded the team that the compliance review for PCI scope is scheduled next Tuesday and we need updated architecture diagrams.',
      'Frank confirmed that the database migration completed successfully overnight with no customer-facing downtime.',
      'Grace noted that query latency on the orders table spiked after the migration and asked for an index review.',
      'Henry volunteered to profile the slow queries and share findings before the end of the week.',
      'Isabel raised a concern about the new color scheme in the checkout flow after multiple usability test participants hesitated at the pay button.',
      'Jack agreed to run another round of A/B tests with higher contrast variants before the marketing launch.',
      'Karen highlighted that machine learning models for fraud detection need more labeled training data from recent chargeback cases.',
      'Leo proposed partnering with the support team to export anonymized ticket transcripts for labeling next sprint.',
      'Maria asked whether we should postpone the loyalty points feature until payment reliability is restored.',
      'Nathan argued that loyalty work can continue in parallel if we staff a dedicated reliability tiger team.',
      'Olivia shared analytics from last week showing a twelve percent drop in completed checkouts on Android devices.',
      'Paul suspected the Android regression is tied to the latest WebView update and will file a bug with reproduction steps.',
      'Quinn requested a dedicated postmortem document for the February outage and a customer communication draft.',
      'Rita reminded everyone that the Q3 budget meeting is tomorrow and each squad should bring updated headcount forecasts.',
      'Sam confirmed the design system planning workshop is moved to Thursday afternoon to avoid conflict with the budget session.',
      'Tina reported progress on accessibility fixes for screen reader users in the account settings screen.',
      'Uma noted that localization for Vietnamese and Spanish is ninety percent complete but legal copy still needs review.',
      'Victor asked for a decision on whether to ship dark mode in the next release or hold it for a polish sprint.',
      'Wendy recommended shipping dark mode behind a feature flag so we can gather telemetry without a full launch.',
      'Xavier proposed we prioritize performance optimization on the home feed until cold start time drops below two seconds.',
      'Yara mentioned that the therapy session notes feature received positive feedback from beta clinicians last week.',
      'Zoe closed the round by asking if there are any blockers before we move to action items and owners.',
    ];

    final words = <String>[];
    final segments = <String>[];
    final buffer = <String>[];
    var snippetIndex = 0;

    while (words.length < wordCount) {
      final snippet = snippets[snippetIndex % snippets.length];
      snippetIndex++;

      for (final word in snippet.split(RegExp(r'\s+'))) {
        if (words.length >= wordCount) break;
        words.add(word);
        buffer.add(word);

        final reachedSegmentSize = buffer.length >= 55;
        final endsSentence = word.endsWith('.');
        if (reachedSegmentSize && endsSentence) {
          segments.add(buffer.join(' '));
          buffer.clear();
        }
      }
    }

    if (buffer.isNotEmpty) {
      segments.add(buffer.join(' '));
    }

    return segments;
  }
}
