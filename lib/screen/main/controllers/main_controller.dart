import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/route/app_route.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/service/crash_recovery_service.dart';

class MainController extends GetxController {
  MainController({CrashRecoveryService? recoveryService})
      : _recoveryService = recoveryService ??
            (Get.isRegistered<CrashRecoveryService>()
                ? Get.find<CrashRecoveryService>()
                : null);

  static const tabRoutes = [
    AppRoutes.live,
    AppRoutes.history,
    AppRoutes.settings,
  ];

  final CrashRecoveryService? _recoveryService;

  final selectedNavIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    Get.rootDelegate.addListener(_onRouteChanged);
    syncFromCurrentRoute();
    unawaited(_runCrashRecovery());
  }

  Future<void> _runCrashRecovery() async {
    final service = _recoveryService;
    if (service == null) return;

    try {
      final recovered = await service.recoverUnsavedSessions();
      if (recovered > 0 && Get.isRegistered<HistoryController>()) {
        await Get.find<HistoryController>().refreshHistory();
      }
    } catch (error, stackTrace) {
      debugPrint('[Transcribe] Crash recovery refresh failed: $error');
      debugPrint('$stackTrace');
    }
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
      if (currentPage == AppRoutes.development) {
        return AppRoutes.settings;
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
