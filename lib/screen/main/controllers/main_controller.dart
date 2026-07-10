import 'package:get/get.dart';

import '../../../arch/route/app_route.dart';

class MainController extends GetxController {
  static const tabRoutes = [
    AppRoutes.live,
    AppRoutes.history,
    AppRoutes.settings,
  ];

  final selectedNavIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    Get.rootDelegate.addListener(_onRouteChanged);
    syncFromCurrentRoute();
  }

  @override
  void onClose() {
    Get.rootDelegate.removeListener(_onRouteChanged);
    super.onClose();
  }

  void _onRouteChanged() => syncFromCurrentRoute();

  void syncFromCurrentRoute() {
    final route = _activeTabRoute;
    final index = tabRoutes.indexOf(route);
    if (index >= 0) {
      selectedNavIndex.value = index;
    }
  }

  String get _activeTabRoute {
    final config = Get.rootDelegate.currentConfiguration;
    final currentPage = config?.currentPage?.name;
    if (currentPage != null) {
      if (tabRoutes.contains(currentPage)) {
        return currentPage;
      }
      if (currentPage.startsWith('${AppRoutes.history}/')) {
        return AppRoutes.history;
      }
    }
    return Get.currentRoute;
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabRoutes.length) return;
    if (selectedNavIndex.value == index) return;
    selectedNavIndex.value = index;
    Get.rootDelegate.offNamed(tabRoutes[index]);
  }
}
