import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionRepository>(
      () => SessionRepositoryImpl(Get.find<DatabaseService>()),
    );
    Get.lazyPut<HistoryRepository>(
      () => HistoryRepository(sessionRepository: Get.find()),
    );
    Get.lazyPut<HistoryController>(
      () => HistoryController(historyRepository: Get.find()),
    );
  }
}
