import 'dart:math';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/utils/logger/app_logger.dart';

/// Helper class to populate the SQLite database with realistic sample data.
class DebugSeed {
  static const _summaries = [
    'The team reviewed the current project progress, discussed upcoming milestones, identified several blockers, and agreed on the next development priorities for the upcoming sprint.',
    'The meeting focused on task ownership, sprint planning, and resolving technical issues. Team members also reviewed recent progress and outlined action items for the next iteration.',
    'Key decisions were made regarding the product roadmap, release timeline, and feature prioritization. The discussion also covered potential risks and strategies to improve delivery efficiency.',
    'Participants shared customer feedback collected over the past week, discussed common user pain points, and agreed to prioritize several high-impact feature requests in the next release.',
    'The session covered application performance improvements, database optimization strategies, and several code refactoring opportunities to improve long-term maintainability.',
    'The team analyzed last week’s analytics, reviewed user engagement metrics, and discussed opportunities to improve onboarding, retention, and overall user experience.',
    'Most of the conversation centered on sprint planning, workload distribution, dependency management, and ensuring that all deliverables remain on schedule before the next release.',
    'The engineering team agreed on the implementation approach for the new authentication flow, reviewed security considerations, and finalized the technical design before development begins.',
    'Several technical challenges were identified during implementation. Different solutions were evaluated, and the team selected the most maintainable approach while documenting future improvements.',
    'The recording captured an open brainstorming session where participants proposed new product ideas, discussed future enhancements, evaluated feasibility, and prioritized features based on business value.',
    'The discussion included updates from multiple departments, highlighted completed work, addressed outstanding issues, and concluded with a clear list of follow-up actions for each team member.',
    'During the meeting, participants reviewed project status, clarified outstanding requirements, resolved open questions, and aligned on the implementation timeline for the remaining development tasks.',
    'The conversation summarized recent development progress, highlighted successful feature deliveries, discussed testing results, and identified areas that require additional validation before release.',
    'The session focused on improving collaboration across the team by reviewing communication processes, identifying workflow bottlenecks, and defining clear responsibilities for upcoming tasks.',
    'The group discussed future product direction, evaluated customer feedback, reviewed technical constraints, and established a roadmap for implementing the most valuable enhancements over the coming months.',
  ];

  static const _sampleSentences = [
    "Hello, welcome to today's standup. anhnh3",
    "Let's start with Alice's update.",
    "We shipped the payment module yesterday.",
    "The client requested a change in the color scheme.",
    "I'll have the PR ready by this afternoon.",
    "Are there any blockers?",
    "Machine learning models need more training data.",
    "Let's review the analytics from last week.",
    "The database migration was successful.",
    "We need to optimize the query performance.",
  ];

  static const _titles = [
    'Team standup',
    'Dr. Okafor — appointment',
    'Lecture — Linguistics 201',
    'Client sync',
    'Therapy session notes',
    'Product roadmap review',
    'Design system planning',
    'Q3 Budget meeting',
  ];

  static final _random = Random();

  /// Populates the database with [sessionCount] sessions.
  /// Each session will have roughly [segmentsPerSession] segments.
  static Future<void> run({
    int sessionCount = 24,
    int segmentsPerSession = 50,
  }) async {
    final sessionRepo = Get.find<SessionRepository>();
    final segmentRepo = Get.find<SegmentRepository>();

    AppLogger.info('🌱 [DebugSeed] Starting database seed...');

    // Check if we already have data
    try {
      final existing = await sessionRepo.getAllSessions(offset: 0, limit: 1);
      if (existing.items.isNotEmpty) {
        AppLogger.info(
            '🌱 [DebugSeed] Database already has data. Skipping seed.');
        return;
      }

      AppLogger.info('🌱 [DebugSeed] running');
      final now = DateTime.now();

      for (int i = 0; i < sessionCount; i++) {
        AppLogger.info('🌱 [DebugSeed] Session ${i + 1}/$sessionCount');
        // Sessions are spread out over the last 30 days
        final startedAt = now.subtract(Duration(days: i, hours: i * 3));
        final startEpoch = startedAt.millisecondsSinceEpoch ~/ 1000;

        // Simulate sessions of 15 to 60 minutes
        final durationSec = 900 + (i * 120 % 2700);
        final endEpoch = startEpoch + durationSec;

        // 1. Create Session
        final sessionId = await sessionRepo.createSession(
          title: _titles[i % _titles.length],
          startedAt: startEpoch,
          language: 'en',
        );

        // Finish session immediately
        await sessionRepo.finishSession(
          id: sessionId,
          endedAt: endEpoch,
          durationSec: durationSec,
        );

        // Add a summary for even-numbered sessions
        await sessionRepo.updateSummary(
          id: sessionId,
          summary: _summaries[_random.nextInt(_summaries.length)],
        );

        // 2. Generate Segments
        final chunkDurationMs = (durationSec * 1000) ~/ segmentsPerSession;
        final segments = <SegmentModel>[];

        for (int j = 0; j < segmentsPerSession; j++) {
          final startMs = j * chunkDurationMs;
          final endMs = startMs + chunkDurationMs;

          segments.add(
            SegmentModel(
              sessionId: sessionId,
              startMs: startMs,
              endMs: endMs,
              text: _sampleSentences[(i + j) % _sampleSentences.length],
              isFinal: true,
              confidence: 0.85 + ((j % 15) / 100),
              // Randomize between 0.85 - 0.99
              createdAt: endEpoch,
            ),
          );
        }

        // Batch insert segments
        await segmentRepo.insertSegments(segments);

        AppLogger.info(
            '🌱 [DebugSeed] Inserted session $sessionId with ${segments.length} segments.');
      }

      AppLogger.info('🌱 [DebugSeed] Database seed complete!');
    } catch (error) {
      AppLogger.error(error: error);
    }
  }
}
