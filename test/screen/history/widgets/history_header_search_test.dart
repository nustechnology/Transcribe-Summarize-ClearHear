import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/history/widgets/history_header.dart';
import 'package:transcribe_summarize_clearhear/screen/history/widgets/history_search_field.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_page_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';

class _FakeHistoryRepository extends HistoryRepository {
  _FakeHistoryRepository()
      : super(
          sessionRepository: _Unused(),
          segmentRepository: _Unused(),
        );

  @override
  Future<HistoryPageResult> fetchSessions({
    required int offset,
    required int limit,
  }) async =>
      const HistoryPageResult(items: [], hasMore: false);

  @override
  Future<List<HistorySearchHit>> searchSessions(String query) async => [];

  @override
  Future<int> deleteSessions(List<String> ids) async => ids.length;

  @override
  Future<bool> updateSessionTitle(String id, String newTitle) async => true;

  @override
  Future<HistoryItem?> getSession(String id) async => null;
}

class _Unused implements SessionRepository, SegmentRepository {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Translation.load();
    Get.locale = const Locale('en', 'US');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  late HistoryController controller;

  setUp(() async {
    controller = HistoryController(
      historyRepository: _FakeHistoryRepository(),
    );
    Get.put(controller);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(Get.reset);

  testWidgets('HistoryTitleBar shows History when not selecting',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: HistoryTitleBar()),
      ),
    );

    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('HistoryTitleBar shows selection actions', (tester) async {
    controller.enterSelectionMode('1');

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: HistoryTitleBar()),
      ),
    );
    await tester.pump();

    expect(find.text('1 items selected'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('HistorySearchField updates controller query', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const Scaffold(body: HistorySearchField()),
      ),
    );

    expect(find.text('Search by title or text...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'standup');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.searchQuery.value, 'standup');
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.searchQuery.value, isEmpty);
  });
}
