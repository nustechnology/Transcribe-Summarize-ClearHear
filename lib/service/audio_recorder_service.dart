import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records microphone audio as 16 kHz mono WAV for Whisper.
class AudioRecorderService {
  AudioRecorder? _recorder;

  static const _recordConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 256000,
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

  Future<String> startRecording() async {
    try {
      final recorder = await _ensureRecorder();
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/caption_${DateTime.now().millisecondsSinceEpoch}.wav';
      await recorder.start(_recordConfig, path: path);
      return path;
    } on MissingPluginException {
      rethrow;
    }
  }

  Future<String?> stopRecording() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    return recorder.stop();
  }

  Future<void> dispose() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      await recorder.dispose();
    }
  }
}
