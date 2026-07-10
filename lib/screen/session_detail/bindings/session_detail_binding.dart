import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/session_detail/controllers/session_detail_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/session_detail/session_detail_dependencies.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';

class SessionDetailBinding extends Bindings {
  @override
  void dependencies() {
    ensureSessionDetailDependencies();

    final sessionId = int.tryParse(
      Get.parameters['id'] ?? '${Get.arguments ?? ''}',
    );
    if (sessionId == null) {
      return;
    }

    Get.lazyPut<SessionDetailController>(
      () => SessionDetailController(
        sessionId: sessionId,
        sessionRepository: Get.find<SessionRepository>(),
        segmentRepository: Get.find<SegmentRepository>(),
        summaryService: Get.find<SessionSummaryService>(),
      ),
    );
  }
}
