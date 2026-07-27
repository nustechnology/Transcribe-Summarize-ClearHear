import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/history/history_widget.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_page_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';

HistoryItem _item(String id, {String title = 'Session'}) {
  return HistoryItem(
    id: id,
    title: title,
    timestamp: DateTime(2026, 1, 1),
    snippet: 'Snippet text',
    summaryStatus: 'ready',
    duration: 60,
    speakerCount: 1,
    category: 'meeting',
  );
}

class _FakeHistoryRepository extends HistoryRepository {
  _FakeHistoryRepository()
      : super(
          sessionRepository: _Unused(),
          segmentRepository: _Unused(),
        );

  final List<HistoryItem> allItems = [];

  @override
  Future<HistoryPageResult> fetchSessions({
    required int offset,
    required int limit,
  }) async {
    final items = allItems.skip(offset).take(limit).toList();
    return HistoryPageResult(
      items: items,
      hasMore: offset + items.length < allItems.length,
    );
  }

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

  tearDown(Get.reset);

  testWidgets('shows empty state when there are no sessions', (tester) async {
    final repository = _FakeHistoryRepository();
    final controller = HistoryController(historyRepository: repository);
    Get.put(controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const HistoryView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ClearHear'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('No saved sessions found.'), findsOneWidget);
    expect(
      find.text('Transcripts are stored securely on your device.'),
      findsOneWidget,
    );
  });

  testWidgets('lists session titles from repository', (tester) async {
    final repository = _FakeHistoryRepository()
      ..allItems.addAll([
        _item('1', title: 'Standup'),
        _item('2', title: 'Design review'),
      ]);
    final controller = HistoryController(historyRepository: repository);
    Get.put(controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: const HistoryView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Design review'), findsOneWidget);
    expect(find.text('Snippet text'), findsNWidgets(2));
  });
}
