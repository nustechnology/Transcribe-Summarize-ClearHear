import 'package:get/get.dart';

import '../../../arch/repository/impl/segment_repository_impl.dart';
import '../../../arch/repository/impl/session_repository_impl.dart';
import '../../../arch/repository/impl/settings_repository_impl.dart';
import '../../../arch/repository/segment_repository.dart';
import '../../../arch/repository/session_repository.dart';
import '../../../arch/repository/settings_repository.dart';
import '../../../service/database_service.dart';
import '../../history/bindings/history_binding.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
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

    Get.lazyPut<HomeController>(() => HomeController());

    // History screen shares the SessionRepository already registered above.
    HistoryBinding().dependencies();
  }
}
