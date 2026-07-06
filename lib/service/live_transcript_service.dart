import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/conversation_segment.dart';
import '../util/pcm_silence_detector.dart';
import 'audio_recorder_service.dart';
import 'conversation_segment_capture.dart';
import 'whisper_kit_service.dart';

typedef LiveTranscriptCallback = void Function(String fullText);

/// Records conversation segments and transcribes them with whisper_kit.
class LiveTranscriptService {
  LiveTranscriptService({
    required AudioRecorderService audioRecorderService,
    required WhisperKitService whisperKitService,
    ConversationSegmentCapture? segmentCapture,
    PcmSilenceDetector? silenceDetector,
  })  : _audioRecorderService = audioRecorderService,
        _whisperKitService = whisperKitService,
        _segmentCapture = segmentCapture ?? ConversationSegmentCapture(),
        _silenceDetector = silenceDetector ?? PcmSilenceDetector();

  final AudioRecorderService _audioRecorderService;
  final WhisperKitService _whisperKitService;
  final ConversationSegmentCapture _segmentCapture;
  final PcmSilenceDetector _silenceDetector;

  bool _isActive = false;
  bool _isPaused = false;

  bool get isPaused => _isPaused;

  Future<void> start({LiveTranscriptCallback? onUpdate}) async {
    if (_isActive) return;

    await _whisperKitService.ensureModelReady();
    await _segmentCapture.start();
    _silenceDetector.reset();
    _isPaused = false;
    try {
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
      _isActive = true;
    } catch (_) {
      _isActive = false;
      rethrow;
    }
  }

  /// Pause recording and transcribe captured segments with WhisperKit.
  Future<LiveTranscriptResult> pause() async {
    if (!_isActive || _isPaused) {
      return _buildCurrentResult();
    }

    _isActive = false;
    _isPaused = true;

    try {
      await _audioRecorderService.stopStreaming();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] pause stop streaming failed: $error');
      debugPrint('$stackTrace');
    }

    await _commitOpenSegment();
    final result = await _transcribePendingSegments();

    debugPrint(
      '[LiveTranscript] paused (${result.segments.length} segments, '
      'whisper=${result.usedWhisper}):\n${result.text}',
    );

    return result;
  }

  /// Resume recording after [pause].
  Future<void> resume() async {
    if (_isActive || !_isPaused) return;

    _silenceDetector.reset();
    try {
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
      _isActive = true;
      _isPaused = false;
    } catch (_) {
      _isActive = false;
      rethrow;
    }
  }

  /// Stop streaming, transcribe saved segments with WhisperKit, log only.
  Future<LiveTranscriptResult> finish() async {
    _isActive = false;
    _isPaused = false;

    if (_audioRecorderService.isStreaming) {
      try {
        await _audioRecorderService.stopStreaming();
      } catch (error, stackTrace) {
        debugPrint('[LiveTranscript] stop streaming failed: $error');
        debugPrint('$stackTrace');
      }
    }

    await _commitOpenSegment();
    final result = await _transcribePendingSegments();

    debugPrint(
      '[LiveTranscript] finished (${result.segments.length} segments, '
      'whisper=${result.usedWhisper}):\n${result.text}',
    );

    return result;
  }

  void _handleChunk(Uint8List chunk) {
    if (!_isActive) return;
    _segmentCapture.append(chunk);
    if (_silenceDetector.feed(chunk)) {
      unawaited(_commitOpenSegment());
    }
  }

  Future<LiveTranscriptResult> _buildCurrentResult() {
    return Future.value(
      LiveTranscriptResult(
        text: _combinedDisplayText(),
        segments: List.unmodifiable(_segmentCapture.segments),
        usedWhisper: _segmentCapture.segments
            .any((segment) => segment.whisperText.trim().isNotEmpty),
      ),
    );
  }

  String _combinedDisplayText() {
    return _segmentCapture.segments
        .map((segment) => segment.displayText)
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  Future<LiveTranscriptResult> _transcribePendingSegments() async {
    final segments = _segmentCapture.segments;
    final pendingSegments = segments
        .where((segment) => segment.whisperText.trim().isEmpty)
        .toList(growable: false);

    var usedWhisper = segments
        .any((segment) => segment.whisperText.trim().isNotEmpty);

    if (pendingSegments.isNotEmpty) {
      try {
        final whisperText = await _whisperKitService
            .buildTranscriptFromSegments(pendingSegments);
        if (whisperText.trim().isNotEmpty) {
          usedWhisper = true;
        }
      } catch (error, stackTrace) {
        debugPrint('[LiveTranscript] WhisperKit segment pass failed: $error');
        debugPrint('$stackTrace');
      }
    }

    return LiveTranscriptResult(
      text: _combinedDisplayText(),
      segments: List.unmodifiable(segments),
      usedWhisper: usedWhisper,
    );
  }

  Future<void> _commitOpenSegment() async {
    final segment = await _segmentCapture.commitCurrent();
    if (segment != null) {
      debugPrint(
        '[LiveTranscript] saved segment ${segment.id}: ${segment.wavPath}',
      );
    }
  }

  void dispose() {
    _isActive = false;
    _isPaused = false;
    unawaited(_segmentCapture.dispose());
  }
}
