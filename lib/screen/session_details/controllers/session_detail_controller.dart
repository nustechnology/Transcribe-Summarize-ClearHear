import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_detail_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';
import 'package:transcribe_summarize_clearhear/service/share_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';
import 'package:transcribe_summarize_clearhear/util/toast/app_toast.dart';

class SessionDetailController extends GetxController {
  SessionDetailController({
    required this.repository,
    required this.shareService,
    required SessionSummaryService summaryService,
    this.sessionId,
  }) : _summaryService = summaryService;

  final SessionDetailRepository repository;
  final ShareService shareService;
  final SessionSummaryService _summaryService;
  final int? sessionId;

  int? get currentSessionId {
    if (sessionId != null) return sessionId;

    final routeId = Get.parameters['id'];
    if (routeId != null && routeId.isNotEmpty) {
      return int.tryParse(routeId);
    }

    final delegateId = Get.rootDelegate
        .currentConfiguration
        ?.currentPage
        ?.parameters?['id'];
    if (delegateId != null && delegateId.isNotEmpty) {
      return int.tryParse(delegateId);
    }

    final location = Get.rootDelegate.currentConfiguration?.uri.toString() ??
        Get.currentRoute;
    final match = RegExp(r'/history/detail/(\d+)').firstMatch(location);
    return int.tryParse(match?.group(1) ?? '');
  }

  final isLoading = true.obs;
  final isDeleting = false.obs;
  final isSharing = false.obs;
  final isTitleEditing = false.obs;
  final isTitleSaving = false.obs;
  final isRetryingSummary = false.obs;
  final errorMessage = ''.obs;
  final session = Rxn<SessionModel>();
  final segments = <SegmentModel>[].obs;

  final isLoadingMore = false.obs;
  final hasMoreSegments = true.obs;

  StreamSubscription<int>? _summaryUpdatesSub;

  int get _pageSize => 20;

  bool get isSummaryProcessing => session.value?.isSummaryProcessing ?? false;

  bool get isShowingSummaryLoading {
    final current = session.value;
    final hasTranscript = segments.any((segment) => segment.text.trim().isNotEmpty);
    final hasSummary = current?.hasSummary ?? false;
    final isOptimisticallyPending =
        current?.summaryStatus == 'idle' &&
            hasTranscript &&
            current?.endedAt != null &&
            !hasSummary;
    return (isSummaryProcessing && !hasSummary) || isOptimisticallyPending;
  }

  bool get isSummaryFailed => session.value?.hasSummaryFailed ?? false;

  bool get isSummaryFailedResource =>
      session.value?.summaryStatus == 'failed_resource';

  String get summaryFailureMessage => isSummaryFailedResource
      ? StringKeys.historyDetailSummaryFailedResource.tr
      : StringKeys.historyDetailSummaryFailed.tr;

  String get summaryText => session.value?.summary?.trim() ?? '';

  @override
  void onInit() {
    super.onInit();
    _summaryUpdatesSub = _summaryService.updates.listen((updatedSessionId) {
      if (updatedSessionId == currentSessionId) {
        unawaited(_refreshSession());
      }
    });
    loadDetail();
  }

  @override
  void onReady() {
    super.onReady();
    if (session.value == null &&
        sessionId == null &&
        currentSessionId != null) {
      unawaited(loadDetail());
    }
  }

  @override
  void onClose() {
    _summaryUpdatesSub?.cancel();
    super.onClose();
  }

  Future<void> loadDetail() async {
    final id = currentSessionId;
    if (id == null) {
      errorMessage.value = StringKeys.somethingWentWrong.tr;
      isLoading.value = false;
      return;
    }

    isLoading.value = session.value == null;
    errorMessage.value = '';

    try {
      final result = await repository.fetchSession(id);
      if (result == null) {
        AppLogger.error(
          error:
              '[loadDetail] Failed to load detail for sessionId=$id: result is null.',
        );
        errorMessage.value = StringKeys.somethingWentWrong.tr;
        session.value = null;
        return;
      }
      session.value = result;
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      errorMessage.value = StringKeys.somethingWentWrong.tr;
      session.value = null;
    } finally {
      isLoading.value = false;
    }

    if (session.value == null) return;

    segments.clear();
    hasMoreSegments.value = true;
    await loadSegmentsPage();
    unawaited(_queueSummaryIfNeeded());
  }

  Future<void> _refreshSession() async {
    final id = currentSessionId;
    if (id == null) return;

    final result = await repository.fetchSession(id);
    if (result != null) {
      session.value = result;
    }
  }

  Future<void> _queueSummaryIfNeeded() async {
    final id = currentSessionId;
    final current = session.value;
    if (id == null || current == null) return;

    final hasTranscript =
        segments.any((segment) => segment.text.trim().isNotEmpty);
    final status = current.summaryStatus;
    final needsSummary =
        (status == 'idle' || status == 'queued' || status == 'processing') &&
        (current.summary?.trim().isEmpty ?? true) &&
        hasTranscript;
    if (needsSummary) {
      unawaited(_summaryService.queue(id));
    }
  }

  Future<void> retrySummary() async {
    final id = currentSessionId;
    if (id == null || isRetryingSummary.value) return;

    isRetryingSummary.value = true;
    try {
      await _summaryService.retry(id);
    } finally {
      isRetryingSummary.value = false;
    }
  }

  Future<void> loadSegmentsPage() async {
    if (isLoadingMore.value || !hasMoreSegments.value) {
      return;
    }

    final id = currentSessionId;
    if (id == null) return;

    isLoadingMore.value = true;
    errorMessage.value = '';

    try {
      final pageSegments = await repository.fetchSegmentsPaged(
        id,
        offset: segments.length,
        limit: _pageSize,
      );
      segments.addAll(pageSegments);
      if (pageSegments.length < _pageSize) {
        hasMoreSegments.value = false;
      }
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> deleteSession() async {
    try {
      if (isDeleting.value || session.value == null) {
        return;
      }
      isDeleting.value = true;
      final id = currentSessionId;
      if (id == null) {
        AppToast.error(StringKeys.somethingWentWrong.tr);
        return;
      }
      final success = await repository.deleteSession(id);
      if (success) {
        if (Get.isRegistered<HistoryController>()) {
          unawaited(Get.find<HistoryController>().refreshHistory());
        }

        Get.rootDelegate.popRoute();
        AppToast.sessionDeleted(
          title: StringKeys.historyDetailDeleteSuccess.tr,
          subtitle: StringKeys.historyDeleteRemovedNote.tr,
        );
      } else {
        AppToast.error(StringKeys.somethingWentWrong.tr);
      }
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      AppToast.error(StringKeys.somethingWentWrong.tr);
    } finally {
      isDeleting.value = false;
    }
  }

  void setTitleEditing(bool value) {
    isTitleEditing.value = value;
  }

  Future<void> updateTitle(String newTitle) async {
    final trimmed = newTitle.trim();
    final currentSession = session.value;
    final id = currentSessionId;
    if (trimmed.isEmpty ||
        currentSession == null ||
        id == null ||
        currentSession.title == trimmed ||
        isTitleSaving.value) {
      return;
    }

    final oldSession = currentSession;
    session.value = currentSession.copyWith(title: trimmed);
    isTitleSaving.value = true;

    try {
      final success = await repository.updateSessionTitle(
        sessionId: id,
        title: trimmed,
      );
      if (!success) throw Exception('updateSessionTitle returned false');

      if (Get.isRegistered<HistoryController>()) {
        unawaited(Get.find<HistoryController>().refreshHistory());
      }
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      session.value = oldSession;
      AppToast.error(StringKeys.somethingWentWrong.tr);
    } finally {
      isTitleSaving.value = false;
    }
  }

  Future<void> shareTranscript({Rect? sharePositionOrigin}) async {
    try {
      if (isSharing.value || session.value == null) {
        return;
      }
      isSharing.value = true;
      final currentSession = session.value;
      final id = currentSessionId;
      if (currentSession == null || id == null) {
        AppToast.error(StringKeys.somethingWentWrong.tr);
        return;
      }

      final exportFile = await repository.exportTranscriptFile(currentSession);
      if (exportFile == null) {
        AppToast.error(StringKeys.historyDetailShareFailed.tr);
        return;
      }

      final result = await shareService.shareFile(
        title: currentSession.title,
        filePath: exportFile.path,
        sharePositionOrigin: sharePositionOrigin,
      );

      if (result == ShareResultStatus.unavailable) {
        AppToast.error(StringKeys.historyDetailShareFailed.tr);
      }
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      AppToast.error(StringKeys.historyDetailShareFailed.tr);
    } finally {
      isSharing.value = false;
    }
  }
}
