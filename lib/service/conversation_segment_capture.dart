import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/pcm_audio_util.dart';
import '../util/wav_util.dart';

/// Buffers PCM per utterance and writes WAV files when a speech pause is detected.
class ConversationSegmentCapture {
  final BytesBuilder _current = BytesBuilder(copy: false);
  final List<ConversationSegment> _segments = [];
  int _nextId = 1;
  String? _sessionDir;

  List<ConversationSegment> get segments => List.unmodifiable(_segments);

  int get currentBufferBytes => _current.length;

  /// Returns a snapshot of the current PCM buffer without clearing it.
  Uint8List peekCurrentPcm() => Uint8List.fromList(_current.toBytes());

  Future<void> start() async {
    await dispose();
    _current.clear();
    _segments.clear();
    _nextId = 1;

    final directory = await getTemporaryDirectory();
    _sessionDir =
        '${directory.path}/conversation_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(_sessionDir!).create(recursive: true);
  }

  void discardCurrent() => _current.clear();

  void append(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _current.add(chunk);
  }

  /// Saves the current utterance buffer as a WAV segment.
  Future<ConversationSegment?> commitCurrent({
    String liveText = '',
    bool force = false,
  }) async {
    final sessionDir = _sessionDir;
    final minBytes = force
        ? MlModelConfig.minFinishSegmentPcmBytes
        : MlModelConfig.minSegmentPcmBytes;
    if (sessionDir == null || _current.length < minBytes) {
      _current.clear();
      return null;
    }

    final pcm = normalizePcm16(_current.toBytes());
    _current.clear();

    final wavPath = '$sessionDir/segment_${_nextId.toString().padLeft(3, '0')}.wav';
    await File(wavPath).writeAsBytes(buildWavFromPcm16(pcm), flush: true);

    debugPrint(
      '[SegmentCapture] segment $_nextId '
      '${durationSecondsForPcm16(pcm.length).toStringAsFixed(2)}s '
      'rms=${rmsPcm16(pcm).toStringAsFixed(0)}',
    );

    final segment = ConversationSegment(
      id: _nextId,
      wavPath: wavPath,
      recordedAt: DateTime.now(),
      liveText: liveText.trim(),
    );
    _nextId++;
    _segments.add(segment);
    return segment;
  }

  Future<void> dispose() async {
    _current.clear();

    for (final segment in _segments) {
      try {
        final file = File(segment.wavPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    final sessionDir = _sessionDir;
    _sessionDir = null;
    if (sessionDir != null) {
      try {
        final dir = Directory(sessionDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }

    _segments.clear();
    _nextId = 1;
  }
}
