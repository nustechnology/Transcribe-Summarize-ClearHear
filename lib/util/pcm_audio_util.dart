import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

/// Converts [audio_waveforms] `onAudioChunks` bytes to mono PCM16 little-endian.
///
/// iOS streams Float32 samples; Android streams PCM16.
Uint8List recorderChunkToPcm16(Uint8List chunk) {
  if (chunk.isEmpty || !Platform.isIOS) return chunk;

  final alignedLength = chunk.length - (chunk.length % 4);
  if (alignedLength < 4) return Uint8List(0);

  final sampleCount = alignedLength ~/ 4;
  final view = ByteData.sublistView(chunk, 0, alignedLength);
  final out = Uint8List(sampleCount * 2);
  final outView = ByteData.sublistView(out);

  for (var i = 0; i < sampleCount; i++) {
    final scaled = (view.getFloat32(i * 4, Endian.little).clamp(-1.0, 1.0) *
            32767)
        .round()
        .clamp(-32768, 32767);
    outView.setInt16(i * 2, scaled, Endian.little);
  }

  return out;
}

/// Converts VAD's float32 samples (range -1..1) to mono PCM16 little-endian
/// bytes, matching the format Whisper/WAV writing expects elsewhere.
Uint8List floatSamplesToPcm16(List<double> samples) {
  final out = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(out);
  for (var i = 0; i < samples.length; i++) {
    final scaled =
        (samples[i].clamp(-1.0, 1.0) * 32767).round().clamp(-32768, 32767);
    view.setInt16(i * 2, scaled, Endian.little);
  }
  return out;
}

/// Peak-normalizes mono PCM16 so quiet mic input is usable by Whisper.
Uint8List normalizePcm16(Uint8List pcm) {
  if (pcm.length < 2) return pcm;

  final sampleCount = pcm.length ~/ 2;
  final view = ByteData.view(
    pcm.buffer,
    pcm.offsetInBytes,
    sampleCount * 2,
  );

  var peak = 0;
  for (var i = 0; i < sampleCount; i++) {
    final sample = view.getInt16(i * 2, Endian.little).abs();
    if (sample > peak) peak = sample;
  }

  // Already loud enough for Whisper.
  if (peak >= 1200) return pcm;

  // Near-silent buffers are unlikely to transcribe.
  if (peak < 32) return pcm;

  final gain = (0.85 * 32767 / peak).clamp(1.0, 48.0);
  final out = Uint8List(pcm.length);
  final outView = ByteData.sublistView(out);

  for (var i = 0; i < sampleCount; i++) {
    final scaled = (view.getInt16(i * 2, Endian.little) * gain)
        .round()
        .clamp(-32768, 32767);
    outView.setInt16(i * 2, scaled, Endian.little);
  }

  return out;
}

double rmsPcm16(Uint8List pcm) {
  if (pcm.length < 2) return 0;

  final sampleCount = pcm.length ~/ 2;
  final view = ByteData.view(
    pcm.buffer,
    pcm.offsetInBytes,
    sampleCount * 2,
  );

  var sumSquares = 0.0;
  for (var i = 0; i < sampleCount; i++) {
    final sample = view.getInt16(i * 2, Endian.little).toDouble();
    sumSquares += sample * sample;
  }

  return math.sqrt(sumSquares / sampleCount);
}

/// RMS energy of mono float32 samples in [-1, 1].
double rmsFloat32(Float32List samples) {
  if (samples.isEmpty) return 0;
  var sumSquares = 0.0;
  for (final sample in samples) {
    sumSquares += sample * sample;
  }
  return math.sqrt(sumSquares / samples.length);
}

/// True when [samples] look like speech rather than silence/noise for
/// speaker-embedding probes.
bool hasSpeechEnergy(
  Float32List samples, {
  double minRms = 0.015,
}) {
  return rmsFloat32(samples) >= minRms;
}

double durationSecondsForPcm16(
  int byteLength, {
  int sampleRate = 16000,
}) {
  final sampleCount = byteLength ~/ 2;
  if (sampleCount <= 0 || sampleRate <= 0) return 0;
  return sampleCount / sampleRate;
}
