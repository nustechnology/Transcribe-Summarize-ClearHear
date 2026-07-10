import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/util/mock_history_data.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';

/// Helper class to populate the SQLite database with realistic sample data.
class DebugSeed {
  static const _sampleSentences = [
    "Hello, welcome to today's standup.",
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

  /// Populates the database with [sessionCount] sessions.
  /// Each session will have roughly [segmentsPerSession] segments.
  static Future<void> run({
    int sessionCount = 24,
    int segmentsPerSession = 50,
  }) async {
    try {
      final dbService = Get.find<DatabaseService>();
      final sessionRepo = SessionRepositoryImpl(dbService);
      final segmentRepo = SegmentRepositoryImpl(dbService);

      AppLogger.info('🌱 [DebugSeed] Starting database seed...');

      if (MockHistoryData.enabled) {
        await _removeStaleMockSessions(sessionRepo);
        await _insertMockSession(
          dbService: dbService,
          sessionRepo: sessionRepo,
          segmentRepo: segmentRepo,
        );
        return;
      }

      final existing = await sessionRepo.getAllSessions(offset: 0, limit: 1);
      if (existing.items.isNotEmpty) {
        AppLogger.info(
          '🌱 [DebugSeed] Database already has data. Skipping seed.',
        );
        return;
      }

      AppLogger.info('🌱 [DebugSeed] running bulk seed');
      final now = DateTime.now();

      for (int i = 0; i < sessionCount; i++) {
        AppLogger.info('🌱 [DebugSeed] Session ${i + 1}/$sessionCount');
        final startedAt = now.subtract(Duration(days: i, hours: i * 3));
        final startEpoch = startedAt.millisecondsSinceEpoch ~/ 1000;

        const durationSec = 1280;
        final endEpoch = startEpoch + durationSec;

        final sessionId = await sessionRepo.createSession(
          title: _titles[i % _titles.length],
          startedAt: startEpoch,
          language: 'en',
        );

        await sessionRepo.finishSession(
          id: sessionId,
          endedAt: endEpoch,
          durationSec: durationSec,
        );

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
              createdAt: endEpoch,
            ),
          );
        }

        await segmentRepo.insertSegments(segments);

        AppLogger.info(
          '🌱 [DebugSeed] Inserted session $sessionId with ${segments.length} segments.',
        );
      }

      AppLogger.info('🌱 [DebugSeed] Database seed complete!');
    } catch (error) {
      AppLogger.error(error: error);
    }
  }

  static Future<void> _removeStaleMockSessions(
    SessionRepositoryImpl sessionRepo,
  ) async {
    final page = await sessionRepo.getAllSessions(offset: 0, limit: 200);
    final staleIds = page.items
        .where((session) => session.title.startsWith('[Mock]'))
        .map((session) => session.id!)
        .toList();
    if (staleIds.isEmpty) return;

    await sessionRepo.deleteSessions(staleIds);
    AppLogger.info(
      '🌱 [DebugSeed] Removed ${staleIds.length} stale mock session(s).',
    );
  }

  static Future<void> _insertMockSession({
    required DatabaseService dbService,
    required SessionRepositoryImpl sessionRepo,
    required SegmentRepositoryImpl segmentRepo,
  }) async {
    AppLogger.info('🌱 [DebugSeed] Inserting mock session for AI summary test');

    if (MockHistoryData.transcriptSegments.isEmpty) {
      AppLogger.warning(
        '🌱 [DebugSeed] No transcript segments configured for mock session.',
      );
      return;
    }

    final now = DateTime.now();
    final startedAt = now.subtract(const Duration(minutes: 12));
    final startEpoch = startedAt.millisecondsSinceEpoch ~/ 1000;
    const durationSec = 1280;
    final endEpoch = startEpoch + durationSec;

    final sessionId = await sessionRepo.createSession(
      title: MockHistoryData.title,
      startedAt: startEpoch,
      language: 'en',
    );

    await sessionRepo.finishSession(
      id: sessionId,
      endedAt: endEpoch,
      durationSec: durationSec,
    );

    if (MockHistoryData.summaryText.trim().isNotEmpty) {
      await sessionRepo.updateSummary(
        id: sessionId,
        summary: MockHistoryData.summaryText,
      );
      final db = await dbService.database;
      await db.update(
        'sessions',
        {'summary_status': 'ready', 'summary_error': null},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    }

    final chunkDurationMs =
        (durationSec * 1000) ~/ MockHistoryData.transcriptSegments.length;
    final segments = <SegmentModel>[];

    for (int j = 0; j < MockHistoryData.transcriptSegments.length; j++) {
      final startMs = j * chunkDurationMs;
      final endMs = startMs + chunkDurationMs;

      segments.add(
        SegmentModel(
          sessionId: sessionId,
          startMs: startMs,
          endMs: endMs,
          text: MockHistoryData.transcriptSegments[j],
          isFinal: true,
          confidence: 0.95,
          createdAt: endEpoch,
        ),
      );
    }

    await segmentRepo.insertSegments(segments);

    final wordCount = MockHistoryData.transcriptSegments
        .join(' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    AppLogger.info(
      '🌱 [DebugSeed] Inserted mock session $sessionId with '
      '${segments.length} segments (~$wordCount words).',
    );
  }
}
