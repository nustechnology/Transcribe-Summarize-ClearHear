import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';

import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<HomeController>()) {
      Get.put<HomeController>(
        HomeController(
          settingsRepository: Get.isRegistered<SettingsRepository>()
              ? Get.find<SettingsRepository>()
              : null,
          sessionRepository: Get.isRegistered<SessionRepository>()
              ? Get.find<SessionRepository>()
              : null,
          segmentRepository: Get.isRegistered<SegmentRepository>()
              ? Get.find<SegmentRepository>()
              : null,
        ),
        permanent: true,
      );
    }
  }
}
