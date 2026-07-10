import 'dart:async';

import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';

class SessionDetailController extends GetxController {
  SessionDetailController({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required SegmentRepository segmentRepository,
    required SessionSummaryService summaryService,
  })  : _sessionRepository = sessionRepository,
        _segmentRepository = segmentRepository,
        _summaryService = summaryService;

  final int sessionId;
  final SessionRepository _sessionRepository;
  final SegmentRepository _segmentRepository;
  final SessionSummaryService _summaryService;

  final session = Rxn<SessionModel>();
  final transcript = ''.obs;
  final isLoading = true.obs;
  final isRetrying = false.obs;

  StreamSubscription<int>? _summaryUpdatesSub;

  bool get isProcessing => session.value?.isSummaryProcessing ?? false;

  bool get isShowingLoading {
    final current = session.value;
    final hasTranscript = transcript.value.trim().isNotEmpty;
    final hasSummary = current?.hasSummary ?? false;
    final isOptimisticallyPending =
        current?.summaryStatus == 'idle' &&
            hasTranscript &&
            current?.endedAt != null &&
            !hasSummary;
    return (isProcessing && !hasSummary) || isOptimisticallyPending;
  }

  bool get isFailed => session.value?.hasSummaryFailed ?? false;

  bool get isFailedResource =>
      session.value?.summaryStatus == 'failed_resource';

  bool get hasSummary => session.value?.hasSummary ?? false;

  String get failureMessage => isFailedResource
      ? 'Summary generation failed due to system resource limits.'
      : 'Summary generation failed.';

  @override
  void onInit() {
    super.onInit();
    _summaryUpdatesSub = _summaryService.updates.listen((updatedSessionId) {
      if (updatedSessionId == sessionId) {
        unawaited(loadSession());
      }
    });
    unawaited(loadSession());
  }

  @override
  void onClose() {
    _summaryUpdatesSub?.cancel();
    super.onClose();
  }

  Future<void> loadSession() async {
    isLoading.value = true;
    try {
      final sessionFuture = _sessionRepository.getSession(sessionId);
      final segmentsFuture = _segmentRepository.getSegments(sessionId);

      final loadedSession = await sessionFuture;
      session.value = loadedSession;

      final segments = await segmentsFuture;
      transcript.value = _joinTranscript(segments);

      final status = loadedSession?.summaryStatus;
      final needsSummary = loadedSession != null &&
          (status == 'idle' || status == 'queued' || status == 'processing') &&
          (loadedSession.summary?.trim().isEmpty ?? true) &&
          transcript.value.trim().isNotEmpty;
      if (needsSummary) {
        unawaited(_summaryService.queue(sessionId));
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> retrySummary() async {
    if (isRetrying.value) return;
    isRetrying.value = true;
    try {
      await _summaryService.retry(sessionId);
    } finally {
      isRetrying.value = false;
    }
  }

  String _joinTranscript(List<SegmentModel> segments) {
    return segments
        .map((segment) => segment.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }
}
