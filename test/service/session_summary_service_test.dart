import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/service/llama_service.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';

import '../helpers/test_database.dart';

class _FakeLlamaService extends LlamaService {
  bool loaded = true;
  String summaryText = 'Team aligned on next steps.';
  Object? error;
  int summarizeCalls = 0;
  int loadCalls = 0;

  @override
  bool get isModelLoaded => loaded;

  @override
  Future<bool> loadBundledModel({
    required void Function(dynamic progress) onProgress,
  }) async {
    loadCalls += 1;
    onProgress(1.0);
    loaded = true;
    return true;
  }

  @override
  Future<bool> loadDefaultModel({
    required void Function(dynamic progress) onProgress,
  }) =>
      loadBundledModel(onProgress: onProgress);

  @override
  Future<String> summarize(String transcript) async {
    summarizeCalls += 1;
    if (error != null) throw error!;
    return summaryText;
  }
}

void main() {
  late TestDatabaseHarness harness;
  late SessionRepositoryImpl sessions;
  late SegmentRepositoryImpl segments;
  late _FakeLlamaService llama;
  late SessionSummaryService summaryService;

  setUp(() async {
    harness = await TestDatabaseHarness.create();
    sessions = SessionRepositoryImpl(harness.databaseService);
    segments = SegmentRepositoryImpl(harness.databaseService);
    llama = _FakeLlamaService();
    summaryService = SessionSummaryService(
      databaseService: harness.databaseService,
      llamaService: llama,
    );
  });

  tearDown(() async {
    summaryService.onClose();
    await harness.dispose();
  });

  Future<int> seedSessionWithTranscript() async {
    final id = await sessions.createSession(title: 'Standup', startedAt: 100);
    await sessions.finishSession(id: id, endedAt: 200, durationSec: 100);
    await segments.insertSegment(
      SegmentModel(
        sessionId: id,
        startMs: 0,
        endMs: 1000,
        text: 'We discussed blockers and owners.',
        createdAt: 100,
      ),
    );
    return id;
  }

  Future<void> waitUntilReady(int sessionId) async {
    for (var i = 0; i < 80; i++) {
      if (summaryService.statusFor(sessionId) == 'ready' ||
          summaryService.isFailed(sessionId)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('queue generates summary and marks session ready', () async {
    final id = await seedSessionWithTranscript();
    final updates = <int>[];
    final sub = summaryService.updates.listen(updates.add);

    await summaryService.queue(id);
    await waitUntilReady(id);

    expect(summaryService.statusFor(id), 'ready');
    expect(summaryService.isProcessing(id), isFalse);
    expect(llama.summarizeCalls, 1);
    expect(updates, contains(id));

    final session = await sessions.getSession(id);
    expect(session?.summaryStatus, 'ready');
    expect(session?.summary, contains('aligned'));

    await sub.cancel();
  });

  test('queue skips when summary already ready unless forced', () async {
    final id = await seedSessionWithTranscript();
    await summaryService.queue(id);
    await waitUntilReady(id);
    final firstCalls = llama.summarizeCalls;

    await summaryService.queue(id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(llama.summarizeCalls, firstCalls);

    await summaryService.retry(id);
    await waitUntilReady(id);
    expect(llama.summarizeCalls, greaterThan(firstCalls));
  });

  test('empty transcript marks failed', () async {
    final id = await sessions.createSession(title: 'Empty', startedAt: 1);

    await summaryService.queue(id);
    await waitUntilReady(id);

    expect(summaryService.isFailed(id), isTrue);
    expect(summaryService.statusFor(id), 'failed');
    expect(summaryService.errorFor(id), isNotNull);
  });

  test('resource-limit errors map to failed_resource', () async {
    final id = await seedSessionWithTranscript();
    llama.error = LlamaServiceException('oom', isResourceLimit: true);

    await summaryService.queue(id);
    await waitUntilReady(id);

    expect(summaryService.statusFor(id), 'failed_resource');
    expect(summaryService.isFailed(id), isTrue);
  });

  test('loads model when not already loaded', () async {
    final id = await seedSessionWithTranscript();
    llama.loaded = false;

    await summaryService.queue(id);
    await waitUntilReady(id);

    expect(llama.loadCalls, 1);
    expect(summaryService.statusFor(id), 'ready');
  });

  test('status helpers default to idle', () {
    expect(summaryService.statusFor(999), 'idle');
    expect(summaryService.isProcessing(999), isFalse);
    expect(summaryService.isFailed(999), isFalse);
    expect(summaryService.errorFor(999), isNull);
  });
}
