import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Captures microphone audio to a temp file for Whisper (via FFmpeg in whisper_ggml).
class AudioRecorderService {
  AudioRecorder? _recorder;
  String? _recordingPath;
  bool _isRecording = false;

  /// Same approach as whisper_ggml example: AAC on disk, FFmpeg converts before inference.
  static const recordConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 128000,
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

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    if (_isRecording) return;

    final recorder = await _ensureRecorder();
    final directory = await getTemporaryDirectory();
    _recordingPath =
        '${directory.path}/caption_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await recorder.start(recordConfig, path: _recordingPath!);
    _isRecording = true;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final recorder = _recorder;
    final path = recorder != null ? await recorder.stop() : _recordingPath;
    _isRecording = false;
    _recordingPath = null;
    return path;
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }

    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      await recorder.dispose();
    }
  }
}
