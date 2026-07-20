import 'package:get/get.dart';

import '../arch/repository/segment_repository.dart';
import '../arch/repository/session_repository.dart';
import '../lang/string_keys.dart';
import '../util/logger/app_logger.dart';
import 'audio_recorder_service.dart';

/// Finalizes sessions that were persisted incrementally but never closed because
/// the app was hard-terminated (crash, kill, battery drain) mid-recording.
class CrashRecoveryService {
  CrashRecoveryService({
    required SessionRepository sessionRepository,
    required SegmentRepository segmentRepository,
  })  : _sessionRepository = sessionRepository,
        _segmentRepository = segmentRepository;

  final SessionRepository _sessionRepository;
  final SegmentRepository _segmentRepository;

  Future<int> recoverUnsavedSessions() async {
    var recovered = 0;
    try {
      final drafts = await _sessionRepository.getUnsavedSessions();
      for (final draft in drafts) {
        try {
          final id = draft.id;
          if (id == null) continue;

          final segments = await _segmentRepository.getSegments(id);
          if (segments.isEmpty) {
            await _sessionRepository.deleteSession(id);
            continue;
          }

          final lastCreatedAt = segments
              .map((segment) => segment.createdAt)
              .fold(draft.startedAt, (a, b) => b > a ? b : a);
          final durationSec = lastCreatedAt > draft.startedAt
              ? lastCreatedAt - draft.startedAt
              : 0;

          await _sessionRepository.markSessionSaved(
            id: id,
            title: _autoTitleFor(draft.startedAt),
            endedAt: lastCreatedAt,
            durationSec: durationSec,
          );
          recovered++;
        } catch (error, stackTrace) {
          AppLogger.error(
            error: error,
            stackTrace: stackTrace,
            tag: 'CrashRecoveryService',
          );
        }
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'CrashRecoveryService',
      );
    }

    await AudioRecorderService.cleanupOrphanRecordings();
    return recovered;
  }

  String _autoTitleFor(int startedAtEpochSec) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(startedAtEpochSec * 1000);
    final formatted = '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return StringKeys.homeSaveSessionAutoTitle.trParams({'date': formatted});
  }
}
