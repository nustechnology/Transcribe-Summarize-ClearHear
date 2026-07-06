import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../util/wav_util.dart';

/// Accumulates PCM in memory and writes one-off WAV snapshots for Whisper.
class LiveWavCapture {
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  String? _latestSnapshotPath;

  int get dataBytes => _pcm.length;

  Future<void> start() async {
    _pcm.clear();
    await _deleteSnapshot();
  }

  void append(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _pcm.add(chunk);
  }

  Uint8List getPcmSnapshot() => Uint8List.fromList(_pcm.toBytes());

  /// Writes a fresh WAV file that Whisper can read without touching live capture.
  Future<String?> writeSnapshot() async {
    if (_pcm.isEmpty) return null;

    await _deleteSnapshot();

    final directory = await getTemporaryDirectory();
    _latestSnapshotPath =
        '${directory.path}/live_snapshot_${DateTime.now().millisecondsSinceEpoch}.wav';

    final file = File(_latestSnapshotPath!);
    await file.writeAsBytes(buildWavFromPcm16(getPcmSnapshot()), flush: true);
    return _latestSnapshotPath;
  }

  Future<void> close() async {
    // PCM buffer is kept until dispose so finish() can still snapshot.
  }

  Future<void> dispose() async {
    _pcm.clear();
    await _deleteSnapshot();
  }

  Future<void> _deleteSnapshot() async {
    final path = _latestSnapshotPath;
    _latestSnapshotPath = null;
    if (path == null) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
