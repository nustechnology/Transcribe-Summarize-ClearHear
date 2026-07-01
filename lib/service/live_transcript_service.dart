import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../config/ml_model_config.dart';
import 'audio_recorder_service.dart';
import 'whisper_service.dart';

typedef LiveTranscriptCallback = void Function(String fullText);

/// Chunked on-device transcription while the microphone is active.
///
/// Rotates the recorder on a fixed schedule and transcribes each chunk in a
/// background queue so recording never waits for Whisper to finish.
class LiveTranscriptService {
  LiveTranscriptService({
    required AudioRecorderService audioRecorderService,
    required WhisperService whisperService,
  })  : _audioRecorderService = audioRecorderService,
        _whisperService = whisperService;

  final AudioRecorderService _audioRecorderService;
  final WhisperService _whisperService;

  final List<String> _segments = [];
  final Queue<String> _pendingChunks = Queue<String>();

  Timer? _chunkTimer;
  Timer? _initialChunkTimer;
  bool _isActive = false;
  bool _isRotating = false;
  bool _isDrainingQueue = false;

  String get fullText => _segments.join(' ').trim();

  Future<void> start({required LiveTranscriptCallback onUpdate}) async {
    if (_isActive) return;

    _segments.clear();
    _pendingChunks.clear();
    _isActive = true;

    void scheduleRotation() => unawaited(_rotateAndEnqueue(onUpdate));

    _initialChunkTimer = Timer(
      MlModelConfig.liveInitialChunkDelay,
      scheduleRotation,
    );

    _chunkTimer = Timer.periodic(
      MlModelConfig.liveChunkInterval,
      (_) => scheduleRotation(),
    );
  }

  Future<void> _rotateAndEnqueue(LiveTranscriptCallback onUpdate) async {
    if (!_isActive || _isRotating) return;

    _isRotating = true;
    try {
      final chunkPath = await _audioRecorderService.rotateChunk();
      if (chunkPath == null || chunkPath.isEmpty) return;

      _pendingChunks.add(chunkPath);
      unawaited(_drainQueue(onUpdate));
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] rotate failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _isRotating = false;
    }
  }

  Future<void> _drainQueue(LiveTranscriptCallback onUpdate) async {
    if (_isDrainingQueue) return;
    _isDrainingQueue = true;

    try {
      while (_pendingChunks.isNotEmpty) {
        final chunkPath = _pendingChunks.removeFirst();
        try {
          await _whisperService.ensureModelReady();
          final text = await _whisperService.transcribeChunk(chunkPath);
          if (text.isEmpty) continue;

          _segments.add(text);
          final combined = fullText;
          debugPrint('[LiveTranscript] chunk: $text');
          debugPrint('[LiveTranscript] full:\n$combined');
          onUpdate(combined);
        } catch (error, stackTrace) {
          debugPrint('[LiveTranscript] chunk failed: $error');
          debugPrint('$stackTrace');
        }
      }
    } finally {
      _isDrainingQueue = false;
    }
  }

  /// Stop timers and transcribe the final recording segment.
  Future<String> finish({LiveTranscriptCallback? onUpdate}) async {
    _isActive = false;
    _initialChunkTimer?.cancel();
    _initialChunkTimer = null;
    _chunkTimer?.cancel();
    _chunkTimer = null;

    while (_isRotating) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    try {
      final finalPath = await _audioRecorderService.stopRecording();
      if (finalPath != null && finalPath.isNotEmpty) {
        _pendingChunks.add(finalPath);
      }
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] stop recording failed: $error');
      debugPrint('$stackTrace');
    }

    if (onUpdate != null) {
      await _drainQueue(onUpdate);
    } else {
      await _drainQueue((_) {});
    }

    final combined = fullText;
    debugPrint('[LiveTranscript] finished:\n$combined');
    return combined;
  }

  void dispose() {
    _isActive = false;
    _initialChunkTimer?.cancel();
    _initialChunkTimer = null;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _pendingChunks.clear();
  }
}
