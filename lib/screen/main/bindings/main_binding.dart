import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/settings_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';

import '../../home/controllers/home_controller.dart';
import '../controllers/main_controller.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
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
          settingsRepository: Get.find<SettingsRepository>(),
          sessionRepository: Get.find<SessionRepository>(),
          segmentRepository: Get.find<SegmentRepository>(),
        ),
        permanent: true,
      );
    }
  }
}
