import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_detail_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/session_detail_dependencies.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/controllers/session_detail_controller.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';
import 'package:transcribe_summarize_clearhear/service/share_service.dart';
import 'package:transcribe_summarize_clearhear/service/transcript_export_service.dart';

int? _sessionIdFromRoute() {
  final paramId = Get.parameters['id'];
  if (paramId != null && paramId.isNotEmpty) {
    return int.tryParse(paramId);
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

class SessionDetailBinding extends Bindings {
  @override
  void dependencies() {
    ensureSessionDetailDependencies();

    if (!Get.isRegistered<SessionDetailRepository>()) {
      Get.lazyPut<SessionDetailRepository>(
        () => SessionDetailRepository(
          sessionRepository: Get.find<SessionRepository>(),
          segmentRepository: Get.find<SegmentRepository>(),
          transcriptExportService: TranscriptExportService(),
        ),
        fenix: true,
      );
    }

    if (Get.isRegistered<SessionDetailController>()) {
      Get.delete<SessionDetailController>(force: true);
    }

    Get.put<SessionDetailController>(
      SessionDetailController(
        sessionId: _sessionIdFromRoute(),
        repository: Get.find<SessionDetailRepository>(),
        shareService: ShareService(),
        summaryService: Get.find<SessionSummaryService>(),
      ),
    );
  }
}
