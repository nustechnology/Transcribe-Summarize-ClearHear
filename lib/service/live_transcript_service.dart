import 'dart:io';

import 'package:flutter/foundation.dart';

import 'audio_recorder_service.dart';
import 'whisper_service.dart';

/// Records microphone audio, then transcribes once when [finish] is called.
class LiveTranscriptService {
  LiveTranscriptService({
    required AudioRecorderService audioRecorderService,
    required WhisperService whisperService,
  })  : _audioRecorderService = audioRecorderService,
        _whisperService = whisperService;

  final AudioRecorderService _audioRecorderService;
  final WhisperService _whisperService;

  bool _isActive = false;

  Future<void> start() async {
    if (_isActive) return;

    _isActive = true;
    await _audioRecorderService.startRecording();
  }

  /// Stop recording and return the final transcript.
  Future<String> finish() async {
    _isActive = false;

    String? audioPath;
    try {
      audioPath = await _audioRecorderService.stopRecording();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] stop recording failed: $error');
      debugPrint('$stackTrace');
      return '';
    }

    if (audioPath == null || audioPath.isEmpty) {
      debugPrint('[LiveTranscript] no audio captured');
      return '';
    }

    try {
      await _whisperService.ensureModelReady();
      final text = await _whisperService.transcribeRecording(audioPath);
      final result = text.trim();
      debugPrint('[LiveTranscript] finished:\n$result');
      return result;
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] final pass failed: $error');
      debugPrint('$stackTrace');
      return '';
    } finally {
      await _deleteQuietly(File(audioPath));
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void dispose() {
    _isActive = false;
  }
}
