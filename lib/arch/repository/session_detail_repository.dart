import 'dart:io';

import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/service/transcript_export_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';

class SessionDetailRepository {
  SessionDetailRepository({
    required SessionRepository sessionRepository,
    required SegmentRepository segmentRepository,
    required TranscriptExportService transcriptExportService,
  })  : _sessionRepository = sessionRepository,
        _segmentRepository = segmentRepository,
        _transcriptExportService = transcriptExportService;

  final SessionRepository _sessionRepository;
  final SegmentRepository _segmentRepository;
  final TranscriptExportService _transcriptExportService;

  Future<SessionModel?> fetchSession(int sessionId) async {
    try {
      return await _sessionRepository.getSession(sessionId);
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<List<SegmentModel>> fetchSegments(int sessionId) async {
    try {
      return await _segmentRepository.getSegments(sessionId);
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return [];
    }
  }

  Future<List<SegmentModel>> fetchSegmentsPaged(
    int sessionId, {
    required int offset,
    required int limit,
  }) async {
    try {
      return await _segmentRepository.getSegmentsPaged(
        sessionId: sessionId,
        offset: offset,
        limit: limit,
      );
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return [];
    }
  }

  Future<bool> deleteSession(int sessionId) async {
    try {
      await _sessionRepository.deleteSession(sessionId);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> updateSessionTitle({
    required int sessionId,
    required String title,
  }) async {
    try {
      await _sessionRepository.updateTitle(id: sessionId, title: title);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<File?> exportTranscriptFile(SessionModel session) async {
    final sessionId = session.id;
    if (sessionId == null) {
      return null;
    }

    try {
      return await _transcriptExportService.exportTextFile(
        session: session,
        loadSegmentsPage: ({required offset, required limit}) {
          return _segmentRepository.getSegmentsPaged(
            sessionId: sessionId,
            offset: offset,
            limit: limit,
          );
        },
      );
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      return null;
    }
  }
}
