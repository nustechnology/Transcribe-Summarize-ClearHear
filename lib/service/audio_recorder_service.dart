import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/ml_model_config.dart';

typedef PcmChunkCallback = void Function(Uint8List chunk);

/// Streams microphone PCM for conversation segment capture.
class AudioRecorderService {
  AudioRecorderService({RecorderController? recorderController})
      : recorderController = recorderController ?? RecorderController();

  final RecorderController recorderController;

  StreamSubscription<Uint8List>? _chunkSubscription;
  String? _recordingPath;
  bool _isStreaming = false;

  static const recorderSettings = RecorderSettings(
    androidEncoderSettings: AndroidEncoderSettings(
      androidEncoder: AndroidEncoder.wav,
    ),
    iosEncoderSettings: IosEncoderSetting(
      iosEncoder: IosEncoder.kAudioFormatLinearPCM,
      linearPCMBitDepth: 16,
      linearPCMIsFloat: false,
      linearPCMIsBigEndian: false,
    ),
    sampleRate: MlModelConfig.audioSampleRate,
  );

  Future<bool> ensurePermission() async {
    try {
      return recorderController.checkPermission();
    } on MissingPluginException {
      rethrow;
    }
  }

  bool get isStreaming => _isStreaming;

  Future<void> startStreaming({required PcmChunkCallback onChunk}) async {
    if (_isStreaming) return;

    final directory = await getTemporaryDirectory();
    final path = p.join(
      directory.path,
      'caption_pcm_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    _recordingPath = path;

    _chunkSubscription = recorderController.onAudioChunks.listen(onChunk);
    await recorderController.record(path: path, recorderSettings: recorderSettings);
    _isStreaming = true;
  }

  Future<void> stopStreaming() async {
    await _chunkSubscription?.cancel();
    _chunkSubscription = null;

    if (_isStreaming) {
      await recorderController.stop();
    }

    final recordingPath = _recordingPath;
    _recordingPath = null;
    if (recordingPath != null) {
      final recordingFile = File(recordingPath);
      if (await recordingFile.exists()) {
        await recordingFile.delete();
      }
    }

    _isStreaming = false;
  }

  Future<void> dispose() async {
    await stopStreaming();
    recorderController.dispose();
  }
}
