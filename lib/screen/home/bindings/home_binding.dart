import 'package:get/get.dart';
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
        ),
        permanent: true,
      );
    }
  }
}
