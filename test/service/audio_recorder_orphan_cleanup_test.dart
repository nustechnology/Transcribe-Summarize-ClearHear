import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:transcribe_summarize_clearhear/service/audio_recorder_service.dart';

import '../helpers/test_database.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('clearhear_orphan_');
    PathProviderPlatform.instance = TestPathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cleanupOrphanRecordings deletes leftover caption_pcm files', () async {
    final orphan = File(p.join(tempDir.path, 'caption_pcm_123.wav'));
    final keep = File(p.join(tempDir.path, 'other_file.txt'));
    await orphan.writeAsString('pcm');
    await keep.writeAsString('keep');

    await AudioRecorderService.cleanupOrphanRecordings();

    expect(await orphan.exists(), isFalse);
    expect(await keep.exists(), isTrue);
  });
}
