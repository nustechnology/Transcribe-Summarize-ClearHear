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

  Future<void> start({LiveTranscriptCallback? onUpdate}) async {
    if (_isActive) return;

    await _whisperKitService.ensureModelReady();
    await _segmentCapture.start();
    _silenceDetector.reset();
    try {
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) {
          if (!_isActive) return;
          _segmentCapture.append(chunk);
          if (_silenceDetector.feed(chunk)) {
            unawaited(_commitOpenSegment());
          }
        },
      );
      _isActive = true;
    } catch (_) {
      _isActive = false;
      rethrow;
    }
  }

  /// Stop streaming, transcribe saved segments with WhisperKit, log only.
  Future<LiveTranscriptResult> finish() async {
    _isActive = false;

    try {
      await _audioRecorderService.stopStreaming();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] stop streaming failed: $error');
      debugPrint('$stackTrace');
    }

    await _commitOpenSegment();
    final segments = _segmentCapture.segments;

    var finalText = '';
    var usedWhisper = false;

    if (segments.isNotEmpty) {
      try {
        final whisperText =
            await _whisperKitService.buildTranscriptFromSegments(segments);
        if (whisperText.trim().isNotEmpty) {
          finalText = whisperText.trim();
          usedWhisper = true;
        }
      } catch (error, stackTrace) {
        debugPrint('[LiveTranscript] WhisperKit segment pass failed: $error');
        debugPrint('$stackTrace');
      }
    }

    debugPrint(
      '[LiveTranscript] finished (${segments.length} segments, '
      'whisper=$usedWhisper):\n$finalText',
    );

    return LiveTranscriptResult(
      text: finalText,
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
    unawaited(_segmentCapture.dispose());
  }
}
