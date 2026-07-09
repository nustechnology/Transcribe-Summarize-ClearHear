import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/settings_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/controllers/settings_controller.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SettingsRepository>()) {
      Get.lazyPut<SettingsRepository>(
        () => SettingsRepositoryImpl(Get.find<DatabaseService>()),
      );
    }
    if (!Get.isRegistered<SessionRepository>()) {
      Get.lazyPut<SessionRepository>(
        () => SessionRepositoryImpl(Get.find<DatabaseService>()),
      );
    }
    Get.lazyPut<SettingsController>(
      () => SettingsController(
        settingsRepository: Get.find(),
        sessionRepository: Get.find(),
      ),
    );
  }
}
