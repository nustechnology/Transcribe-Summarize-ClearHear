import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/asr_text_util.dart';
import '../util/pcm_silence_detector.dart';
import 'audio_recorder_service.dart';
import 'conversation_segment_capture.dart';
import 'whisper_kit_service.dart';

typedef LiveTranscriptCallback = void Function(String fullText);

double _computeNormalizedRms(Uint8List pcmBytes) {
  if (pcmBytes.length < 2) return 0.0;
  final view = ByteData.view(
    pcmBytes.buffer,
    pcmBytes.offsetInBytes,
    pcmBytes.length,
  );
  var sumSquares = 0.0;
  final sampleCount = pcmBytes.length ~/ 2;
  for (var i = 0; i < pcmBytes.length; i += 2) {
    final sample = view.getInt16(i, Endian.little).toDouble();
    sumSquares += sample * sample;
  }
  final rms = math.sqrt(sumSquares / sampleCount);
  // Log-scale normalize: practical speech sits 300–5000 RMS.
  const maxRms = 6000.0;
  return (math.log(1 + rms) / math.log(1 + maxRms)).clamp(0.0, 1.0);
}

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

  /// Single lock: only one WhisperKit inference runs at a time.
  bool _inferencing = false;

  Timer? _partialTimer;
  DateTime? _lastCommitTime;

  void Function(String)? _onPartial;
  void Function(String text, bool isNewParagraph)? _onFinal;
  void Function(double amplitude)? _onAmplitude;

  Future<void> start({
    void Function(String partial)? onPartial,
    void Function(String text, bool isNewParagraph)? onFinal,
    void Function(double amplitude)? onAmplitude,
  }) async {
    if (_isActive) return;

    await _whisperKitService.ensureModelReady();
    await _segmentCapture.start();
    _silenceDetector.reset();
    _isActive = true;
    _lastCommitTime = null;
    _onPartial = onPartial;
    _onFinal = onFinal;
    _onAmplitude = onAmplitude;

    final maxBytes =
        (MlModelConfig.maxSegmentSeconds * MlModelConfig.pcmBytesPerSecond)
            .round();

    _partialTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (!_isActive || _inferencing) return;
      unawaited(_emitPartial());
    });

    await _audioRecorderService.startStreaming(
      onChunk: (chunk) {
        if (!_isActive) return;
        _segmentCapture.append(chunk);
        _onAmplitude?.call(_computeNormalizedRms(chunk));
        final silenceBoundary = _silenceDetector.feed(chunk);
        final maxReached =
            _segmentCapture.currentBufferBytes >= maxBytes;
        if (silenceBoundary || maxReached) {
          _silenceDetector.reset();
          unawaited(_commitAndTranscribe());
        }
      },
    );
  }

  // Require at least 2s of audio for partial transcription to avoid
  // sending noise-only buffers to whisper which can produce invalid UTF-8
  // and crash the native library (SIGABRT).
  static const _minPartialPcmBytes =
      MlModelConfig.audioSampleRate * 2 * 2; // 2s at 16kHz 16-bit mono

  Future<void> _emitPartial() async {
    _inferencing = true;
    try {
      final pcm = _segmentCapture.peekCurrentPcm();
      if (pcm.length < _minPartialPcmBytes) return;
      // Skip if RMS is too low — silence/noise would cause whisper to produce
      // garbage tokens including invalid UTF-8 bytes.
      if (_computeNormalizedRms(pcm) < 0.05) return;
      final text = await _whisperKitService.transcribePcmBytes(pcm);
      if (_isActive && text.isNotEmpty) {
        _onPartial?.call(text);
      }
    } catch (_) {
    } finally {
      _inferencing = false;
    }
  }

  Future<void> _commitAndTranscribe() async {
    if (_inferencing) return;
    _inferencing = true;
    try {
      final segment = await _segmentCapture.commitCurrent();
      if (segment == null) return;

      final now = DateTime.now();
      final isNewParagraph = _lastCommitTime != null &&
          now.difference(_lastCommitTime!).inMilliseconds >
              MlModelConfig.paragraphBreakMs;
      _lastCommitTime = now;

      debugPrint(
          '[LiveTranscript] saved segment ${segment.id}: ${segment.wavPath}');

      try {
        final text = await _whisperKitService.transcribeWav(segment.wavPath);
        segment.whisperText = text;
        if (text.isNotEmpty && _isActive) {
          _onFinal?.call(text, isNewParagraph);
        }
      } catch (e, st) {
        debugPrint('[LiveTranscript] Real-time transcription failed: $e');
        debugPrint('$st');
      }
    } finally {
      _inferencing = false;
    }
  }

  /// Stop streaming, finalize any open segment, return result.
  Future<LiveTranscriptResult> finish() async {
    _isActive = false;
    _partialTimer?.cancel();
    _partialTimer = null;

    if (_audioRecorderService.isStreaming) {
      try {
        await _audioRecorderService.stopStreaming();
      } catch (error, stackTrace) {
        debugPrint('[LiveTranscript] stop streaming failed: $error');
        debugPrint('$stackTrace');
      }
    }

    // Transcribe any remaining open segment
    await _commitAndTranscribe();

    final segments = _segmentCapture.segments;
    final usedWhisper = segments.any((s) => s.whisperText.isNotEmpty);

    debugPrint(
      '[LiveTranscript] finished (${segments.length} segments, '
      'whisper=$usedWhisper):\n${_combinedDisplayText()}',
    );

    return LiveTranscriptResult(
      text: _combinedDisplayText(),
      segments: List.unmodifiable(segments),
      usedWhisper: usedWhisper,
    );
  }

  String _combinedDisplayText() {
    return joinSegmentTexts(
      _segmentCapture.segments.map((segment) => segment.displayText),
    );
  }

  void dispose() {
    _isActive = false;
    _partialTimer?.cancel();
    _partialTimer = null;
    unawaited(_segmentCapture.dispose());
  }
}
