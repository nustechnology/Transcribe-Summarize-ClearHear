import 'package:flutter/foundation.dart';

import 'audio_recorder_service.dart';
import 'sherpa_onnx_service.dart';

typedef LiveTranscriptCallback = void Function(String fullText);

/// Realtime on-device captioning with sherpa_onnx streaming ASR.
class LiveTranscriptService {
  LiveTranscriptService({
    required AudioRecorderService audioRecorderService,
    required SherpaOnnxService sherpaOnnxService,
  })  : _audioRecorderService = audioRecorderService,
        _sherpaOnnxService = sherpaOnnxService;

  final AudioRecorderService _audioRecorderService;
  final SherpaOnnxService _sherpaOnnxService;

  bool _isActive = false;

  Future<void> start({required LiveTranscriptCallback onUpdate}) async {
    if (_isActive) return;

    await _sherpaOnnxService.ensureModelReady();
    _sherpaOnnxService.startSession();
    _isActive = true;

    await _audioRecorderService.startStreaming(
      onChunk: (chunk) {
        if (!_isActive) return;
        final text = _sherpaOnnxService.processPcmChunk(chunk);
        if (text.isNotEmpty) {
          onUpdate(text);
        }
      },
    );
  }

  /// Stop streaming and return the final caption text.
  Future<String> finish({LiveTranscriptCallback? onUpdate}) async {
    _isActive = false;

    try {
      await _audioRecorderService.stopStreaming();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] stop streaming failed: $error');
      debugPrint('$stackTrace');
    }

    final result = _sherpaOnnxService.finishSession();
    if (result.isNotEmpty) {
      onUpdate?.call(result);
    }

    debugPrint('[LiveTranscript] finished:\n$result');
    return result;
  }

  void dispose() {
    _isActive = false;
  }
}
