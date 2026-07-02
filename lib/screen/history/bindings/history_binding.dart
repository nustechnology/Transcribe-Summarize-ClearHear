import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryRepository>(() => HistoryRepository());
    Get.lazyPut<HistoryController>(
      () => HistoryController(historyRepository: Get.find()),
    );
  }
}
