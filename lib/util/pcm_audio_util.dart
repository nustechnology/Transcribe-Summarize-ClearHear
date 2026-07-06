import 'dart:math' as math;
import 'dart:typed_data';

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

double durationSecondsForPcm16(
  int byteLength, {
  int sampleRate = 16000,
}) {
  final sampleCount = byteLength ~/ 2;
  if (sampleCount <= 0 || sampleRate <= 0) return 0;
  return sampleCount / sampleRate;
}
