import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/settings_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import '../../../arch/repository/history_repository.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/main_controller.dart';
import '../../../service/crash_recovery_service.dart';
import '../../../service/llama_service.dart';
import '../../../service/session_summary_service.dart';

class MainBinding extends Bindings {
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
        () => HistoryRepository(sessionRepository: Get.find()),
      );
    }
    if (!Get.isRegistered<CrashRecoveryService>()) {
      Get.lazyPut<CrashRecoveryService>(
        () => CrashRecoveryService(
          sessionRepository: Get.find(),
          segmentRepository: Get.find(),
        ),
      );
    }
    Get.lazyPut<MainController>(() => MainController());
    if (!Get.isRegistered<SessionRepository>()) {
      Get.lazyPut<SessionRepository>(
        () => SessionRepositoryImpl(Get.find<DatabaseService>()),
      );
    }
    if (!Get.isRegistered<SegmentRepository>()) {
      Get.lazyPut<SegmentRepository>(
        () => SegmentRepositoryImpl(Get.find<DatabaseService>()),
      );
    }
    if (!Get.isRegistered<SettingsRepository>()) {
      Get.lazyPut<SettingsRepository>(
        () => SettingsRepositoryImpl(Get.find<DatabaseService>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(
        HomeController(
          llamaService: Get.find<LlamaService>(),
          settingsRepository: Get.find<SettingsRepository>(),
          sessionRepository: Get.find<SessionRepository>(),
          segmentRepository: Get.find<SegmentRepository>(),
        ),
        permanent: true,
      );
    }
  }
}
