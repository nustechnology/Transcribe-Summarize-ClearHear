import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:transcribe_summarize_clearhear/shared/builders/transcript_share_builder.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';

typedef SegmentPageLoader = Future<List<SegmentModel>> Function({
  required int offset,
  required int limit,
});

class TranscriptExportService {
  static const defaultPageSize = 500;
  static const _retentionDuration = Duration(days: 7);

  Future<File> exportTextFile({
    required SessionModel session,
    required SegmentPageLoader loadSegmentsPage,
    int pageSize = defaultPageSize,
  }) async {
    final directory = await _exportDirectory();
    final file = await _resolveExportFile(directory, session);
    await _writeSessionMetadata(file, session);
    await _cleanupStaleExports(directory, keepFile: file);
    final sink = file.openWrite();

    try {
      sink.write('${TranscriptShareBuilder.buildHeader(session)}\n');

      var offset = 0;
      var hasTranscript = false;

      while (true) {
        final page = await loadSegmentsPage(offset: offset, limit: pageSize);
        if (page.isEmpty) {
          break;
        }

        for (final segment in page) {
          if (hasTranscript) {
            sink.write('\n');
          }
          sink.write(TranscriptShareBuilder.buildSegmentLine(segment));
          hasTranscript = true;
        }

        offset += page.length;
        if (page.length < pageSize) {
          break;
        }
      }

      if (!hasTranscript) {
        sink.write(TranscriptShareBuilder.noTranscriptFallback());
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    return file;
  }

  Future<Directory> _exportDirectory() async {
    final tempDirectory = await getTemporaryDirectory();
    final directory =
        Directory(p.join(tempDirectory.path, 'clearhear_exports'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _resolveExportFile(
      Directory directory, SessionModel session) async {
    final baseName = _fileName(session);
    final baseFile = File(p.join(directory.path, baseName));

    if (!await baseFile.exists()) {
      return baseFile;
    }

    final metadataFile = File('${baseFile.path}.meta');
    final existingSessionId = await _readSessionMetadata(metadataFile);
    final currentSessionId = session.id?.toString();

    if (currentSessionId != null && existingSessionId == currentSessionId) {
      return baseFile;
    }

    final timestamp = DateFormat('HHmmss').format(DateTime.now());
    final extension = p.extension(baseName);
    final stem = p.basenameWithoutExtension(baseName);
    var suffix = 1;
    var candidate =
        File(p.join(directory.path, '${stem}_$timestamp$extension'));

    while (await candidate.exists()) {
      candidate = File(
        p.join(directory.path, '${stem}_${timestamp}_$suffix$extension'),
      );
      suffix += 1;
    }

    return candidate;
  }

  Future<void> _writeSessionMetadata(File file, SessionModel session) async {
    final metadataFile = File('${file.path}.meta');
    await metadataFile.writeAsString(session.id?.toString() ?? 'unknown');
  }

  Future<String?> _readSessionMetadata(File metadataFile) async {
    if (!await metadataFile.exists()) {
      return null;
    }

    try {
      return (await metadataFile.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cleanupStaleExports(
    Directory directory, {
    required File keepFile,
  }) async {
    if (!await directory.exists()) {
      return;
    }

    final cutoff = DateTime.now().subtract(_retentionDuration);
    final entities = await directory.list().toList();

    for (final entity in entities) {
      if (entity is! File || entity.path == keepFile.path) {
        continue;
      }

      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (_) {
        // Ignore transient filesystem errors during cleanup.
      }
    }
  }

  String _fileName(SessionModel session) {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      session.startedAt * 1000,
    );
    final date = DateFormat('yyyy-MM-dd').format(startedAt);
    final title = _sanitizeFileName(session.title);
    return '${title}_$date.txt';
  }

  String _sanitizeFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');

    if (sanitized.isEmpty) {
      return 'clearhear_session';
    }

    return sanitized.length > 48 ? sanitized.substring(0, 48) : sanitized;
  }
}
