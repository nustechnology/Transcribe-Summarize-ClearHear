import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../model/conversation_segment.dart';
import '../util/asr_text_util.dart';
import '../util/pcm_audio_util.dart';
import 'audio_recorder_service.dart';
import 'conversation_segment_capture.dart';
import 'sherpa_onnx_service.dart';

/// Records audio and transcribes in real time via [SherpaOnnxService].
///
/// Each audio chunk is fed into sherpa-onnx's streaming recognizer.
/// Partial text is emitted immediately after every decode cycle
/// (truly real-time). Utterance boundaries are detected via
/// sherpa-onnx's built-in endpoint detection.
class LiveTranscriptService {
  LiveTranscriptService({
    required AudioRecorderService audioRecorderService,
    required SherpaOnnxService sherpaOnnxService,
    ConversationSegmentCapture? segmentCapture,
    this.onPartialText,
    this.onSegmentFinalized,
  })  : _audioRecorderService = audioRecorderService,
        _sherpaOnnxService = sherpaOnnxService,
        _segmentCapture = segmentCapture ?? ConversationSegmentCapture();

  final AudioRecorderService _audioRecorderService;
  final SherpaOnnxService _sherpaOnnxService;
  final ConversationSegmentCapture _segmentCapture;

  void Function(String partialText)? onPartialText;
  void Function(ConversationSegment segment)? onSegmentFinalized;

  OnlineStream? _stream;

  bool _isActive = false;
  bool _isPaused = false;

  bool get isPaused => _isPaused;

  Future<void> start() async {
    if (_isActive) return;

    await _sherpaOnnxService.ensureModelReady();
    _segmentCapture.start();
    _isPaused = false;

    _stream = _sherpaOnnxService.createStream();

    _isActive = true;
    try {
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
    } catch (error) {
      _isActive = false;
      rethrow;
    }
  }

  Future<LiveTranscriptResult> pause() async {
    if (!_isActive || _isPaused) return _buildCurrentResult();

    _isActive = false;
    onPartialText?.call('');

    try {
      await _audioRecorderService.stopStreaming();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] pause stop streaming failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }

    _isPaused = true;
    _flushRemainingAudio();

    final result = _buildCurrentResult();
    debugPrint(
      '[LiveTranscript] paused '
      '(${result.segments.length} segments, asr=${result.usedAsr})',
    );
    if (kDebugMode) {
      debugPrint('[LiveTranscript] paused text:\n${result.text}');
    }
    return result;
  }

  Future<void> resume() async {
    if (_isActive || !_isPaused) return;

    _stream = _sherpaOnnxService.createStream();
    _isActive = true;
    try {
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
      _isPaused = false;
    } catch (error) {
      _isActive = false;
      rethrow;
    }
  }

  Future<LiveTranscriptResult> finish() async {
    _isActive = false;
    _isPaused = false;
    onPartialText?.call('');

    if (_audioRecorderService.isStreaming) {
      await _audioRecorderService.stopStreaming();
    }

    _flushRemainingAudio();

    final result = _buildCurrentResult();
    debugPrint(
      '[LiveTranscript] finished '
      '(${result.segments.length} segments, asr=${result.usedAsr})',
    );
    if (kDebugMode) {
      debugPrint('[LiveTranscript] finished text:\n${result.text}');
    }
    return result;
  }

  void _handleChunk(Uint8List chunk) {
    if (!_isActive) return;

    final pcm = recorderChunkToPcm16(chunk);
    if (pcm.isEmpty) return;

    final stream = _stream;
    if (stream == null) return;

    final samples = pcm16ToFloat32(pcm);
    _sherpaOnnxService.acceptWaveform(stream, samples);

    final text = _sherpaOnnxService.decodeAndGetText(stream);
    if (text.isNotEmpty) {
      onPartialText?.call(text);
    }

    if (_sherpaOnnxService.isEndpoint(stream)) {
      final finalText = _sherpaOnnxService.finalizeStream(stream);
      if (finalText.isNotEmpty) {
        final segment = _segmentCapture.commitSegment(text: finalText);
        onSegmentFinalized?.call(segment);
        onPartialText?.call('');
      }
    }
  }

  void _flushRemainingAudio() {
    final stream = _stream;
    if (stream == null) return;

    _stream = null;

    stream.inputFinished();

    final text = _sherpaOnnxService.decodeAndGetText(stream);
    if (text.isNotEmpty) {
      final segment = _segmentCapture.commitSegment(text: text);
      onSegmentFinalized?.call(segment);
    }
  }

  LiveTranscriptResult _buildCurrentResult() {
    return LiveTranscriptResult(
      text: _combinedDisplayText(),
      segments: List.unmodifiable(_segmentCapture.segments),
      usedAsr: _segmentCapture.segments.any((s) => s.hasText),
    );
  }

  String _combinedDisplayText() {
    return joinSegmentTexts(
      _segmentCapture.segments.map((s) => s.displayText),
    );
  }

  Future<void> dispose() async {
    _isActive = false;
    _isPaused = false;
    _stream = null;
    try {
      if (_audioRecorderService.isStreaming) {
        await _audioRecorderService.stopStreaming();
      }
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] dispose stop streaming failed: $error');
      debugPrint('$stackTrace');
    }
    _segmentCapture.dispose();
  }
}

Float32List pcm16ToFloat32(Uint8List pcm) {
  final sampleCount = pcm.length ~/ 2;
  final result = Float32List(sampleCount);
  final view = ByteData.sublistView(pcm);
  for (var i = 0; i < sampleCount; i++) {
    result[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return result;
}
