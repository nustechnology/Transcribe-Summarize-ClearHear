import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_detail_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/session_details/controllers/session_detail_controller.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/service/share_service.dart';
import 'package:transcribe_summarize_clearhear/service/transcript_export_service.dart';

class SessionDetailBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SessionRepository>()) {
      Get.lazyPut<SessionRepository>(
        () => SessionRepositoryImpl(Get.find<DatabaseService>()),
        fenix: true,
      );
    }

    if (!Get.isRegistered<SegmentRepository>()) {
      Get.lazyPut<SegmentRepository>(
        () => SegmentRepositoryImpl(Get.find<DatabaseService>()),
        fenix: true,
      );
    }

    Get.lazyPut<SessionDetailRepository>(
      () => SessionDetailRepository(
        sessionRepository: Get.find(),
        segmentRepository: Get.find(),
        transcriptExportService: TranscriptExportService(),
      ),
      fenix: true,
    );

    Get.lazyPut<SessionDetailController>(
      fenix: true,
      () => SessionDetailController(
        repository: Get.find(),
        shareService: ShareService(),
      ),
    );
  }
}
