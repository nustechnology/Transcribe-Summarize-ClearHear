import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/util/wav_util.dart';

void main() {
  group('buildWavHeader', () {
    test('writes a 44-byte mono PCM16 header', () {
      final header = buildWavHeader(dataSize: 32000);

      expect(header.length, wavHeaderSize);
      expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(header.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(header.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(header.sublist(36, 40)), 'data');

      final view = ByteData.sublistView(header);
      expect(view.getUint32(4, Endian.little), wavHeaderSize + 32000 - 8);
      expect(view.getUint16(20, Endian.little), 1); // PCM
      expect(view.getUint16(22, Endian.little), 1); // mono
      expect(view.getUint32(24, Endian.little), 16000);
      expect(view.getUint16(34, Endian.little), 16);
      expect(view.getUint32(40, Endian.little), 32000);
    });
  });

  group('buildWavFromPcm16', () {
    test('prefixes PCM with a valid WAV header', () {
      final pcm = Uint8List.fromList([0, 1, 2, 3]);
      final wav = buildWavFromPcm16(pcm);

      expect(wav.length, wavHeaderSize + pcm.length);
      expect(wav.sublist(wavHeaderSize), pcm);
    });

    test('pads odd-length PCM to even byte count', () {
      final pcm = Uint8List.fromList([0, 1, 2]);
      final wav = buildWavFromPcm16(pcm);

      expect(wav.length, wavHeaderSize + 4);
      expect(wav[wavHeaderSize + 3], 0);

      final view = ByteData.sublistView(wav);
      expect(view.getUint32(40, Endian.little), 4);
    });
  });
}
