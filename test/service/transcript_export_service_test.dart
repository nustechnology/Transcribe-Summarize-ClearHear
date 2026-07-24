import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:transcribe_summarize_clearhear/service/transcript_export_service.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late Directory tempRoot;
  late TranscriptExportService service;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempRoot = await Directory.systemTemp.createTemp('clearhear_export_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    service = TranscriptExportService();
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  const session = SessionModel(
    id: 42,
    title: 'Team Sync / Notes',
    startedAt: 1700000000,
    summary: 'Covered roadmap',
    summaryStatus: 'ready',
    createdAt: 1700000000,
  );

  test('exportTextFile writes header and paged segment lines', () async {
    final segments = [
      const SegmentModel(
        sessionId: 42,
        startMs: 5000,
        endMs: 8000,
        text: 'Hello',
        speakerLabel: 'Speaker 1',
        createdAt: 1,
      ),
      const SegmentModel(
        sessionId: 42,
        startMs: 65000,
        endMs: 70000,
        text: 'Next',
        createdAt: 2,
      ),
    ];

    final file = await service.exportTextFile(
      session: session,
      pageSize: 1,
      loadSegmentsPage: ({required offset, required limit}) async {
        return segments.skip(offset).take(limit).toList();
      },
    );

    final content = await file.readAsString();
    expect(content, contains('Team Sync / Notes'));
    expect(content, contains('[00:05] Speaker 1: Hello'));
    expect(content, contains('[01:05] Next'));
    expect(file.path, contains('clearhear_exports'));
    expect(p.basename(file.path), startsWith('Team_Sync__Notes_'));
    expect(await File('${file.path}.meta').readAsString(), '42');
  });

  test('exportTextFile writes fallback when there are no segments', () async {
    final file = await service.exportTextFile(
      session: session,
      loadSegmentsPage: ({required offset, required limit}) async => const [],
    );

    final content = await file.readAsString();
    expect(content, contains('No transcript is available yet.'));
  });

  test('exportTextFile reuses file for same session id', () async {
    Future<File> exportOnce() {
      return service.exportTextFile(
        session: session,
        loadSegmentsPage: ({required offset, required limit}) async => const [],
      );
    }

    final first = await exportOnce();
    final second = await exportOnce();
    expect(second.path, first.path);
  });

  test('exportTextFile collides to a new path for a different session id',
      () async {
    Future<File> export(SessionModel model) {
      return service.exportTextFile(
        session: model,
        loadSegmentsPage: ({required offset, required limit}) async => const [],
      );
    }

    final first = await export(session);
    final second = await export(session.copyWith(id: 99));
    expect(second.path, isNot(first.path));
  });
}
