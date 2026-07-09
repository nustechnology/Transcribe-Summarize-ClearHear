import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_kit/download_model.dart';
import 'package:whisper_kit/whisper_kit.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/asr_text_util.dart';
import '../util/pcm_audio_util.dart';
import '../util/wav_util.dart';

/// Top-level relay so [Whisper]'s download callback stays isolate-sendable.
void Function(int received, int total)? _whisperDownloadProgressSink;

void _relayWhisperDownloadProgress(int received, int total) {
  if (total <= 0) return;
  final pct = (received / total * 100).toStringAsFixed(0);
  debugPrint('[WhisperKit] model download $pct%');
  _whisperDownloadProgressSink?.call(received, total);
}

/// Offline transcription of saved conversation segments via [whisper_kit].
class WhisperKitService {
  /// Called while the Whisper model is downloading (received bytes, total bytes).
  void Function(int received, int total)? onDownloadProgress;

  Whisper? _whisper;
  WhisperModel? _whisperModel;
  String? _modelFilePath;
  bool _modelReady = false;
  bool _disposed = false;
  Future<void>? _loading;
  Future<void>? _nativeQueue;

  static const _minModelBytes = 1024 * 1024;

  Future<void> ensureModelReady() {
    if (_disposed) {
      throw StateError('WhisperKitService has been disposed');
    }
    return _loading ??= _loadModel();
  }

  Future<void> _loadModel() {
    return _enqueueNative(() async {
      if (_modelReady) return;

      try {
        _whisperDownloadProgressSink = onDownloadProgress;
        _whisperModel = _resolveWhisperModel(MlModelConfig.whisperModelName);
        _whisper = Whisper(
          model: _whisperModel!,
          onDownloadProgress: _relayWhisperDownloadProgress,
        );

        await _whisper!.getVersion();
        _modelFilePath = await _ensureModelFileOnDisk(_whisperModel!);
        _modelReady = true;
        debugPrint(
          '[WhisperKit] model ready (${MlModelConfig.whisperModelName}) '
          'at $_modelFilePath',
        );
      } catch (error, stackTrace) {
        _whisper = null;
        _whisperModel = null;
        _modelFilePath = null;
        _modelReady = false;
        debugPrint('[WhisperKit] model load failed: $error');
        debugPrint('$stackTrace');
        rethrow;
      } finally {
        _whisperDownloadProgressSink = null;
        _loading = null;
      }
    });
  }

  Future<String> _ensureModelFileOnDisk(WhisperModel model) async {
    final modelDir = await _modelDirectory();
    final modelFile = File(model.getPath(modelDir.path));

    if (!modelFile.existsSync() || modelFile.lengthSync() < _minModelBytes) {
      await downloadModel(
        model: model,
        destinationPath: modelDir.path,
        onDownloadProgress: _relayWhisperDownloadProgress,
      );
    }

    if (!modelFile.existsSync()) {
      throw StateError('Whisper model file is missing after download');
    }

    final size = await modelFile.length();
    if (size < _minModelBytes) {
      throw StateError(
        'Whisper model file is too small ($size bytes): ${modelFile.path}',
      );
    }

    return modelFile.path;
  }

  Future<Directory> _modelDirectory() async {
    if (Platform.isAndroid) {
      return getApplicationSupportDirectory();
    }
    return getLibraryDirectory();
  }

  Future<String> transcribeWav(String wavPath) async {
    await _ensureReadyForTranscribe();
    return _enqueueNative(() => _transcribeWavImpl(wavPath));
  }

  /// Loads the model and verifies the on-disk file before entering the native queue.
  ///
  /// Must not be called from inside [_enqueueNative]; [ensureModelReady] also
  /// queues work and would deadlock with an in-flight transcription task.
  Future<void> _ensureReadyForTranscribe() async {
    await ensureModelReady();

    final modelPath = _modelFilePath;
    if (modelPath == null) {
      throw StateError('WhisperKit model is not ready');
    }

    final modelFile = File(modelPath);
    if (!await modelFile.exists() || await modelFile.length() < _minModelBytes) {
      debugPrint('[WhisperKit] model file missing before transcribe, reloading');
      _modelReady = false;
      _loading = null;
      await ensureModelReady();
    }

    if (_whisper == null || _modelFilePath == null) {
      throw StateError('WhisperKit model is not ready');
    }
  }

  Future<String> _transcribeWavImpl(String wavPath) async {
    if (_disposed) {
      throw StateError('WhisperKitService has been disposed');
    }

    final wavFile = File(wavPath);
    if (!await wavFile.exists()) {
      debugPrint('[WhisperKit] WAV file missing, skipping: $wavPath');
      return '';
    }

    final wavBytes = await wavFile.length();
    final pcmBytes = wavBytes > wavHeaderSize ? wavBytes - wavHeaderSize : 0;
    if (pcmBytes < MlModelConfig.minSegmentPcmBytes) {
      debugPrint(
        '[WhisperKit] skipping short audio ($pcmBytes pcm bytes): $wavPath',
      );
      return '';
    }

    final durationSec = durationSecondsForPcm16(
      pcmBytes,
      sampleRate: MlModelConfig.audioSampleRate,
    );
    debugPrint(
      '[WhisperKit] transcribing $wavPath '
      '(${durationSec.toStringAsFixed(2)}s, $wavBytes bytes)',
    );

    final whisper = _whisper;
    final modelPath = _modelFilePath;
    if (whisper == null || modelPath == null) {
      throw StateError('WhisperKit model is not ready');
    }

    try {
      final result = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: wavPath,
          language: MlModelConfig.whisperLanguage,
          isNoTimestamps: true,
          isVerbose: kDebugMode,
          threads: MlModelConfig.whisperThreadsForPlatform,
          nProcessors: 1,
        ),
      );

      final text = _extractTranscriptText(result);
      if (text.isEmpty) {
        debugPrint('[WhisperKit] empty transcript for $wavPath');
      }
      return formatAsrText(text);
    } on TranscriptionException catch (error, stackTrace) {
      debugPrint('[WhisperKit] transcribe failed for $wavPath: $error');
      debugPrint('$stackTrace');
      return '';
    }
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

    return joinSegmentTexts(lines);
  }

  Future<T> _enqueueNative<T>(Future<T> Function() action) {
    final operation = (_nativeQueue ?? Future<void>.value()).then((_) {
      return action();
    });
    _nativeQueue = operation.then(
      (_) {},
      onError: (_) {},
    );
    return operation;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final pending = _nativeQueue;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }

    _whisperDownloadProgressSink = null;
    _whisper = null;
    _whisperModel = null;
    _modelFilePath = null;
    _modelReady = false;
    _loading = null;
    _nativeQueue = null;
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
