import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/shared/builders/transcript_share_builder.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  const session = SessionModel(
    id: 1,
    title: 'Team Sync',
    startedAt: 1700000000,
    durationSec: 125,
    summary: 'Covered roadmap.',
    summaryStatus: 'ready',
    createdAt: 1700000000,
  );

  const segments = [
    SegmentModel(
      sessionId: 1,
      startMs: 5000,
      endMs: 8000,
      text: 'Hello everyone',
      speakerLabel: 'Speaker 1',
      createdAt: 1,
    ),
    SegmentModel(
      sessionId: 1,
      startMs: 65000,
      endMs: 70000,
      text: 'Next topic',
      createdAt: 1,
    ),
  ];

  group('TranscriptShareBuilder.buildSegmentLine', () {
    test('includes speaker when present', () {
      expect(
        TranscriptShareBuilder.buildSegmentLine(segments[0]),
        '[00:05] Speaker 1: Hello everyone',
      );
    });

    test('omits speaker when absent', () {
      expect(
        TranscriptShareBuilder.buildSegmentLine(segments[1]),
        '[01:05] Next topic',
      );
    });
  });

  group('TranscriptShareBuilder.build', () {
    test('includes title, summary, and segment lines', () {
      final text = TranscriptShareBuilder.build(
        session: session,
        segments: segments,
      );

      expect(text, startsWith('Team Sync\n'));
      expect(text, contains('Covered roadmap.'));
      expect(text, contains('[00:05] Speaker 1: Hello everyone'));
      expect(text, contains('[01:05] Next topic'));
    });

    test('uses no-transcript fallback when segments are empty', () {
      final text = TranscriptShareBuilder.build(
        session: session,
        segments: const [],
      );

      expect(text, contains('No transcript is available yet.'));
    });

    test('uses summary placeholder when summary is missing', () {
      const noSummary = SessionModel(
        id: 1,
        title: 'Team Sync',
        startedAt: 1700000000,
        durationSec: 125,
        summaryStatus: 'idle',
        createdAt: 1700000000,
      );

      final text = TranscriptShareBuilder.build(
        session: noSummary,
        segments: const [],
      );

      expect(text, contains('No summary is available for this file.'));
    });
  });
}
