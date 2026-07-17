import 'package:get/get.dart';

import '../../../service/llama_service.dart';
import '../controllers/development_controller.dart';

class DevelopmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DevelopmentController>(
      () => DevelopmentController(llamaService: Get.find<LlamaService>()),
    );
  }
}
