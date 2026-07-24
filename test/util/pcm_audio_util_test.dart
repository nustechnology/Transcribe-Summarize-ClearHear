import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/util/pcm_audio_util.dart';

void main() {
  group('floatSamplesToPcm16', () {
    test('converts float samples in [-1, 1] to little-endian PCM16', () {
      final pcm = floatSamplesToPcm16([0.0, 1.0, -1.0]);
      final view = ByteData.sublistView(pcm);

      expect(pcm.length, 6);
      expect(view.getInt16(0, Endian.little), 0);
      expect(view.getInt16(2, Endian.little), 32767);
      expect(view.getInt16(4, Endian.little), -32767);
    });

    test('clamps out-of-range floats', () {
      final pcm = floatSamplesToPcm16([2.0, -2.0]);
      final view = ByteData.sublistView(pcm);

      expect(view.getInt16(0, Endian.little), 32767);
      expect(view.getInt16(2, Endian.little), -32767);
    });
  });

  group('normalizePcm16', () {
    test('leaves already-loud buffers unchanged', () {
      final pcm = floatSamplesToPcm16([0.5, -0.5, 0.4]);
      expect(normalizePcm16(pcm), same(pcm));
    });

    test('leaves near-silent buffers unchanged', () {
      final pcm = floatSamplesToPcm16([0.0001, -0.0001]);
      expect(normalizePcm16(pcm), same(pcm));
    });

    test('boosts quiet but audible buffers', () {
      final quiet = floatSamplesToPcm16([0.01, -0.01, 0.008]);
      final normalized = normalizePcm16(quiet);

      expect(normalized, isNot(same(quiet)));
      expect(rmsPcm16(normalized), greaterThan(rmsPcm16(quiet)));
    });
  });

  group('rmsFloat32 / rmsPcm16', () {
    test('returns 0 for empty input', () {
      expect(rmsFloat32(Float32List(0)), 0);
      expect(rmsPcm16(Uint8List(0)), 0);
    });

    test('computes RMS for constant-magnitude samples', () {
      final samples = Float32List.fromList([0.5, -0.5, 0.5, -0.5]);
      expect(rmsFloat32(samples), closeTo(0.5, 1e-9));
    });
  });

  group('durationSecondsForPcm16', () {
    test('converts byte length to seconds at 16 kHz', () {
      // 16000 samples * 2 bytes = 1 second
      expect(durationSecondsForPcm16(32000), 1.0);
      expect(durationSecondsForPcm16(16000), 0.5);
    });

    test('returns 0 for empty or invalid input', () {
      expect(durationSecondsForPcm16(0), 0);
      expect(durationSecondsForPcm16(100, sampleRate: 0), 0);
    });
  });
}
