import 'dart:typed_data';

const wavHeaderSize = 44;

/// PCM WAV header for mono 16-bit audio (matches record's WaveContainer layout).
Uint8List buildWavHeader({
  required int dataSize,
  int sampleRate = 16000,
  int numChannels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final fileSize = wavHeaderSize + dataSize;
  final riffChunkSize = fileSize - 8;

  final header = Uint8List(wavHeaderSize);
  final view = ByteData.sublistView(header);

  void writeString(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header[offset + i] = value.codeUnitAt(i);
    }
  }

  writeString(0, 'RIFF');
  view.setUint32(4, riffChunkSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, numChannels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);
  writeString(36, 'data');
  view.setUint32(40, dataSize, Endian.little);

  return header;
}

/// Builds a mono 16-bit PCM WAV at 16 kHz for Whisper.
Uint8List buildWavFromPcm16(
  Uint8List pcm, {
  int sampleRate = 16000,
  int numChannels = 1,
  int bitsPerSample = 16,
}) {
  final padded = pcm.length.isOdd
      ? Uint8List.fromList([...pcm, 0])
      : pcm;
  final header = buildWavHeader(
    dataSize: padded.length,
    sampleRate: sampleRate,
    numChannels: numChannels,
    bitsPerSample: bitsPerSample,
  );

  final wav = Uint8List(header.length + padded.length);
  wav.setRange(0, header.length, header);
  wav.setRange(header.length, wav.length, padded);
  return wav;
}
