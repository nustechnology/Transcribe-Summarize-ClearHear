import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/screen/home/controllers/home_controller.dart';

void main() {
  test('HomeController increments counter', () {
    final controller = HomeController();
    Get.put(controller);

    expect(controller.counter.value, 0);
    controller.increment();
    expect(controller.counter.value, 1);

    Get.reset();
  });
}
