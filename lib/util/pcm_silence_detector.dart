import 'dart:math' as math;
import 'dart:typed_data';

import '../config/ml_model_config.dart';

/// Detects utterance boundaries from PCM16 chunks using simple energy thresholds.
class PcmSilenceDetector {
  PcmSilenceDetector({
    int sampleRate = MlModelConfig.audioSampleRate,
    double pauseSilenceSeconds = MlModelConfig.pauseSilenceSeconds,
    this.speechRmsThreshold = 350,
  })  : _pauseSampleCount = (sampleRate * pauseSilenceSeconds).round();

  final int speechRmsThreshold;
  final int _pauseSampleCount;

  int _silentSampleCount = 0;
  bool _hasSpeech = false;

  void reset() {
    _silentSampleCount = 0;
    _hasSpeech = false;
  }

  /// Returns true when trailing silence indicates the current utterance ended.
  bool feed(Uint8List pcmBytes) {
    if (pcmBytes.isEmpty) return false;

    final sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount == 0) return false;

    final sampleByteLength = sampleCount * 2;
    final view = ByteData.view(
      pcmBytes.buffer,
      pcmBytes.offsetInBytes,
      sampleByteLength,
    );

    var sumSquares = 0.0;
    for (var i = 0; i < sampleByteLength; i += 2) {
      final sample = view.getInt16(i, Endian.little).toDouble();
      sumSquares += sample * sample;
    }

    final rms = math.sqrt(sumSquares / sampleCount);
    if (rms >= speechRmsThreshold) {
      _hasSpeech = true;
      _silentSampleCount = 0;
      return false;
    }

    _silentSampleCount += sampleCount;
    if (_hasSpeech && _silentSampleCount >= _pauseSampleCount) {
      _hasSpeech = false;
      _silentSampleCount = 0;
      return true;
    }

    return false;
  }
}
