import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../config/ml_model_config.dart';

typedef PcmChunkCallback = void Function(Uint8List chunk);

/// Streams microphone PCM for sherpa_onnx realtime captioning.
class AudioRecorderService {
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _streamSubscription;
  bool _isStreaming = false;

  static const streamConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: MlModelConfig.sherpaSampleRate,
    numChannels: 1,
  );

  Future<AudioRecorder> _ensureRecorder() async {
    _recorder ??= AudioRecorder();
    return _recorder!;
  }

  Future<bool> ensurePermission() async {
    try {
      final recorder = await _ensureRecorder();
      return recorder.hasPermission();
    } on MissingPluginException {
      rethrow;
    }
  }

  bool get isStreaming => _isStreaming;

  Future<void> startStreaming({required PcmChunkCallback onChunk}) async {
    if (_isStreaming) return;

    final recorder = await _ensureRecorder();
    final stream = await recorder.startStream(streamConfig);
    _streamSubscription = stream.listen(onChunk);
    _isStreaming = true;
  }

  Future<void> stopStreaming() async {
    _streamSubscription?.cancel();
    _streamSubscription = null;

    final recorder = _recorder;
    if (recorder != null && _isStreaming) {
      await recorder.stop();
    }

    _isStreaming = false;
  }

  Future<void> dispose() async {
    await stopStreaming();
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      await recorder.dispose();
    }
  }
}
