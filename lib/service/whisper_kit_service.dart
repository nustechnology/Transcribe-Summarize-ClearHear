import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_kit/whisper_kit.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/asr_text_util.dart';
import '../util/pcm_audio_util.dart';
import '../util/wav_util.dart';

/// Offline transcription of saved conversation segments via [whisper_kit].
class WhisperKitService {
  Whisper? _whisper;
  bool _modelReady = false;
  Future<void>? _loading;

  Future<void> ensureModelReady() {
    return _loading ??= _loadModel();
  }

  Future<void> _loadModel() async {
    if (_modelReady) return;

    try {
      _whisper = Whisper(
        model: _resolveWhisperModel(MlModelConfig.whisperModelName),
        onDownloadProgress: (received, total) {
          if (total <= 0) return;
          final pct = (received / total * 100).toStringAsFixed(0);
          debugPrint('[WhisperKit] model download $pct%');
        },
      );

      await _whisper!.getVersion();
      _modelReady = true;
      debugPrint('[WhisperKit] model ready (${MlModelConfig.whisperModelName})');
    } catch (error, stackTrace) {
      _whisper = null;
      _modelReady = false;
      debugPrint('[WhisperKit] model load failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    } finally {
      _loading = null;
    }
  }

  /// Transcribes raw PCM bytes by writing a temporary WAV file.
  Future<String> transcribePcmBytes(Uint8List pcm) async {
    final tmpDir = await getTemporaryDirectory();
    final tmpPath =
        '${tmpDir.path}/partial_${DateTime.now().millisecondsSinceEpoch}.wav';
    try {
      await File(tmpPath).writeAsBytes(buildWavFromPcm16(pcm));
      return await transcribeWav(tmpPath);
    } finally {
      try {
        await File(tmpPath).delete();
      } catch (_) {}
    }
  }

  Future<String> transcribeWav(String wavPath) async {
    await ensureModelReady();

    final whisper = _whisper;
    if (whisper == null) {
      throw StateError('WhisperKit model is not ready');
    }

    final wavFile = File(wavPath);
    if (!await wavFile.exists()) {
      throw StateError('WAV file not found: $wavPath');
    }

    final wavBytes = await wavFile.length();
    final durationSec = durationSecondsForPcm16(
      wavBytes > wavHeaderSize ? wavBytes - wavHeaderSize : 0,
      sampleRate: MlModelConfig.audioSampleRate,
    );
    debugPrint(
      '[WhisperKit] transcribing $wavPath '
      '(${durationSec.toStringAsFixed(2)}s, $wavBytes bytes)',
    );

    final result = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        language: MlModelConfig.whisperLanguage,
        isNoTimestamps: true,
        isVerbose: kDebugMode,
        threads: MlModelConfig.whisperThreads,
      ),
    );

    final text = _extractTranscriptText(result);
    if (text.isEmpty) {
      debugPrint('[WhisperKit] empty transcript for $wavPath');
    }
    return formatAsrText(text);
  }

  /// Transcribes each saved segment and returns the combined transcript.
  Future<String> buildTranscriptFromSegments(
    List<ConversationSegment> segments,
  ) async {
    if (segments.isEmpty) return '';

    final lines = <String>[];
    for (final segment in segments) {
      if (segment.whisperText.isNotEmpty) {
        lines.add(segment.whisperText);
        continue;
      }
      try {
        final text = await transcribeWav(segment.wavPath);
        segment.whisperText = text;
        if (text.isNotEmpty) {
          lines.add(text);
          debugPrint('[WhisperKit] segment ${segment.id}: $text');
        }
      } catch (error, stackTrace) {
        debugPrint('[WhisperKit] segment ${segment.id} failed: $error');
        debugPrint('$stackTrace');
        if (segment.liveText.isNotEmpty) {
          lines.add(segment.liveText);
        }
      }
    }

    return joinSegmentTexts(lines);
  }

  void dispose() {
    _whisper = null;
    _modelReady = false;
    _loading = null;
  }
}

WhisperModel _resolveWhisperModel(String name) {
  switch (name) {
    case 'base':
      return WhisperModel.base;
    case 'small':
      return WhisperModel.small;
    case 'medium':
      return WhisperModel.medium;
    default:
      return WhisperModel.tiny;
  }
}

String _extractTranscriptText(WhisperTranscribeResponse result) {
  final direct = result.text.trim();
  if (direct.isNotEmpty) return direct;

  final segments = result.segments;
  if (segments == null || segments.isEmpty) return '';

  return segments
      .map((segment) => segment.text.trim())
      .where((text) => text.isNotEmpty)
      .join(' ');
}
