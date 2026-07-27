import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/route/app_route.dart';
import 'package:transcribe_summarize_clearhear/screen/main/controllers/main_controller.dart';
import 'package:transcribe_summarize_clearhear/service/crash_recovery_service.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';

class _FakeCrashRecovery extends CrashRecoveryService {
  _FakeCrashRecovery()
      : super(
          sessionRepository: _UnusedSessionRepository(),
          segmentRepository: _UnusedSegmentRepository(),
        );

  int recoverCalls = 0;
  int recoveredCount = 0;

  @override
  Future<int> recoverUnsavedSessions() async {
    recoverCalls += 1;
    return recoveredCount;
  }
}

class _UnusedSessionRepository implements SessionRepository {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedSegmentRepository implements SegmentRepository {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCrashRecovery recovery;

  setUp(() {
    recovery = _FakeCrashRecovery();
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('onInit runs crash recovery', (tester) async {
    recovery.recoveredCount = 1;

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.live,
        getPages: [
          for (final route in MainController.tabRoutes)
            GetPage(name: route, page: () => const SizedBox.shrink()),
        ],
      ),
    );

    Get.put(MainController(recoveryService: recovery));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(recovery.recoverCalls, 1);
  });

  test('selectTab ignores out-of-range indexes', () {
    final controller = MainController(recoveryService: recovery);
    controller.selectedNavIndex.value = 0;
    controller.selectTab(-1);
    controller.selectTab(99);
    expect(controller.selectedNavIndex.value, 0);
  });

  test('selectTab no-ops when selecting the same tab', () {
    final controller = MainController(recoveryService: recovery);
    controller.selectedNavIndex.value = 1;
    controller.selectTab(1);
    expect(controller.selectedNavIndex.value, 1);
  });

  test('tabRoutes expose live history settings', () {
    expect(
      MainController.tabRoutes,
      [AppRoutes.live, AppRoutes.history, AppRoutes.settings],
    );
  });
}
