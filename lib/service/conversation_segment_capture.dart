import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/pcm_audio_util.dart';
import '../util/wav_util.dart';

/// Writes complete utterances (as detected by VAD) to WAV files on disk.
class ConversationSegmentCapture {
  final List<ConversationSegment> _segments = [];
  int _nextId = 1;
  String? _sessionDir;

  List<ConversationSegment> get segments => List.unmodifiable(_segments);

  Future<void> start() async {
    await dispose();
    _segments.clear();
    _nextId = 1;

    final directory = await getTemporaryDirectory();
    _sessionDir =
        '${directory.path}/conversation_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(_sessionDir!).create(recursive: true);
  }

  /// Saves a complete utterance (VAD's `onSpeechEnd` float32 samples) as a
  /// WAV segment.
  Future<ConversationSegment?> commitSamples(List<double> samples) async {
    final sessionDir = _sessionDir;
    if (sessionDir == null || samples.isEmpty) return null;

    final pcm = normalizePcm16(floatSamplesToPcm16(samples));
    if (pcm.length < MlModelConfig.minSegmentPcmBytes) return null;

    final wavPath =
        '$sessionDir/segment_${_nextId.toString().padLeft(3, '0')}.wav';
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
    );
    _nextId++;
    _segments.add(segment);
    return segment;
  }

  /// Writes the still-in-progress utterance buffer to a fixed, overwritten
  /// path so it can be re-decoded for partial text without touching the
  /// finalized segment sequence.
  Future<String> writePartialWav(Uint8List pcm) async {
    final sessionDir = _sessionDir;
    if (sessionDir == null) {
      throw StateError('Capture session not started');
    }

    final normalized = normalizePcm16(pcm);
    final wavPath = '$sessionDir/partial_live.wav';
    await File(wavPath).writeAsBytes(buildWavFromPcm16(normalized), flush: true);
    return wavPath;
  }

  Future<void> dispose() async {
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
