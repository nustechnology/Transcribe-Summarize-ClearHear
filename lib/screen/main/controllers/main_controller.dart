import 'package:get/get.dart';

class MainController extends GetxController {
  final selectedNavIndex = 0.obs;

  void selectTab(int index) {
    if (index == selectedNavIndex.value) return;
    selectedNavIndex.value = index;
  }
}
