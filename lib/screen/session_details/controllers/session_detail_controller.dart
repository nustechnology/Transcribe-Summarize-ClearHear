import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_detail_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/service/share_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';
import 'package:transcribe_summarize_clearhear/util/toast/app_toast.dart';

class SessionDetailController extends GetxController {
  SessionDetailController({
    required this.repository,
    required this.shareService,
    this.sessionId,
  });

  final SessionDetailRepository repository;
  final ShareService shareService;
  final int? sessionId;

  int? get currentSessionId {
    final routeId = Get.parameters['id'];
    if (routeId != null && routeId.isNotEmpty) {
      return int.tryParse(routeId);
    }
    return sessionId;
  }

  final isLoading = false.obs;
  final isDeleting = false.obs;
  final isSharing = false.obs;
  final isTitleEditing = false.obs;
  final isTitleSaving = false.obs;
  final errorMessage = ''.obs;
  final session = Rxn<SessionModel>();
  final segments = <SegmentModel>[].obs;

  final isLoadingMore = false.obs;
  final hasMoreSegments = true.obs;

  int get _pageSize => 20;

  @override
  void onInit() {
    super.onInit();
    loadDetail();
  }

  Future<void> loadDetail() async {
    isLoading.value = true;
    errorMessage.value = '';
    session.value = null;
    segments.clear();
    hasMoreSegments.value = true;

    try {
      final id = currentSessionId;
      if (id == null) {
        errorMessage.value = StringKeys.somethingWentWrong.tr;
        return;
      }

      final result = await repository.fetchSession(id);
      if (result == null) {
        AppLogger.error(
          error:
              '[loadDetail] Failed to load detail for sessionId=$id: result is null.',
        );
        errorMessage.value = StringKeys.somethingWentWrong.tr;
        return;
      }
      AppLogger.info("[loadDetail] result=${result.toString()}");
      session.value = result;
      await loadSegmentsPage();
    } catch (error, stackTrace) {
      AppLogger.error(error: error, stackTrace: stackTrace);
      errorMessage.value = StringKeys.somethingWentWrong.tr;
    } finally {
      isLoading.value = false;
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

        AppToast.success(StringKeys.historyDetailDeleteSuccess.tr);
        Get.rootDelegate.popRoute();
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
