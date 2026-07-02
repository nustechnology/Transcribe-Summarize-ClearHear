import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/screen/history/bindings/history_binding.dart';

import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    HistoryBinding().dependencies();
  }
}
