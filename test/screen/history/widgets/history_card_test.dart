import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/history_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/translation.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/history/widgets/history_card.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_item.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_page_result.dart';
import 'package:transcribe_summarize_clearhear/shared/models/history_search_hit.dart';

HistoryItem _item({
  String id = '1',
  String title = 'Session',
  String snippet = 'Hello preview',
  String summaryStatus = 'ready',
  String category = 'meeting',
}) {
  return HistoryItem(
    id: id,
    title: title,
    timestamp: DateTime(2026, 1, 1, 10),
    snippet: snippet,
    summaryStatus: summaryStatus,
    duration: 125,
    speakerCount: 2,
    category: category,
  );
}

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

  testWidgets('renders title, snippet, and duration', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: HistoryCard(item: _item()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session'), findsOneWidget);
    expect(find.text('Hello preview'), findsOneWidget);
    expect(find.text('02:05'), findsOneWidget);
  });

  testWidgets('shows generating placeholder for processing summary',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: HistoryCard(
            item: _item(summaryStatus: 'processing', snippet: ''),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[Generating summary...]'), findsOneWidget);
  });

  testWidgets('shows checkbox in selection mode', (tester) async {
    controller.enterSelectionMode('1');

    await tester.pumpWidget(
      GetMaterialApp(
        translations: Translation.instance,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: HistoryCard(item: _item()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('HistoryBadge uses meeting icon for meeting category',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HistoryBadge(category: HistoryCategories.meeting),
        ),
      ),
    );

    expect(find.byIcon(Icons.history_edu), findsOneWidget);
  });

  testWidgets('HistoryMetadataChip shows icon and text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HistoryMetadataChip(
            icon: Icons.access_time,
            text: '2m 5s',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.access_time), findsOneWidget);
    expect(find.text('2m 5s'), findsOneWidget);
  });
}
