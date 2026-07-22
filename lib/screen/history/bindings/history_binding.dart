import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/service/llama_service.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<LlamaService>()) {
      Get.put<LlamaService>(LlamaService(), permanent: true);
    }
    if (!Get.isRegistered<SessionSummaryService>()) {
      Get.put<SessionSummaryService>(
        SessionSummaryService(
          databaseService: Get.find<DatabaseService>(),
          llamaService: Get.find<LlamaService>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<SegmentRepository>()) {
      Get.lazyPut<SegmentRepository>(
        () => SegmentRepositoryImpl(Get.find<DatabaseService>()),
      );
    }
    if (!Get.isRegistered<SessionRepository>()) {
      Get.lazyPut<SessionRepository>(
        () => SessionRepositoryImpl(
          Get.find<DatabaseService>(),
        ),
      );
    }
    if (!Get.isRegistered<HistoryRepository>()) {
      Get.lazyPut<HistoryRepository>(
        () => HistoryRepository(
          sessionRepository: Get.find(),
          segmentRepository: Get.find(),
        ),
      );
    }
    Get.lazyPut<HistoryController>(
      () => HistoryController(historyRepository: Get.find<HistoryRepository>()),
    );
  }
}
