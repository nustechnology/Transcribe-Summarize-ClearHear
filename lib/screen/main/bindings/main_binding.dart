import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/settings_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';

import '../../home/controllers/home_controller.dart';
import '../controllers/main_controller.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    // DatabaseService is already registered as permanent in main.dart.

    // Register repositories (Service → Repository order per AGENTS.md).
    Get.lazyPut<SessionRepository>(
      () => SessionRepositoryImpl(Get.find<DatabaseService>()),
    );
    Get.lazyPut<SegmentRepository>(
      () => SegmentRepositoryImpl(Get.find<DatabaseService>()),
    );
    Get.lazyPut<SettingsRepository>(
      () => SettingsRepositoryImpl(Get.find<DatabaseService>()),
    );
    Get.lazyPut<HistoryRepository>(
      () => HistoryRepository(sessionRepository: Get.find()),
    );

    Get.lazyPut<MainController>(() => MainController());
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<HistoryController>(
      () => HistoryController(historyRepository: Get.find()),
    );
  }
}
