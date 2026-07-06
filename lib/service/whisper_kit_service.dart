import 'package:flutter/foundation.dart';
import 'package:whisper_kit/whisper_kit.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/asr_text_util.dart';

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

  Future<String> transcribeWav(String wavPath) async {
    await ensureModelReady();

    final whisper = _whisper;
    if (whisper == null) {
      throw StateError('WhisperKit model is not ready');
    }

    final result = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        language: MlModelConfig.whisperLanguage,
        isNoTimestamps: true,
        threads: MlModelConfig.whisperThreads,
      ),
    );

    return formatAsrText(result.text);
  }

  /// Transcribes each saved segment and returns the combined transcript.
  Future<String> buildTranscriptFromSegments(
    List<ConversationSegment> segments,
  ) async {
    if (segments.isEmpty) return '';

    final lines = <String>[];
    for (final segment in segments) {
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

    return lines.join('\n');
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
