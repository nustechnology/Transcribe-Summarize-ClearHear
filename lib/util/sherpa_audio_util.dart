import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies a bundled asset to app support dir (required by sherpa_onnx on device).
Future<String> copySherpaAssetFile(String assetPath) async {
  final directory = await getApplicationSupportDirectory();
  final target = p.join(directory.path, p.basename(assetPath));
  final file = File(target);

  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  if (!file.existsSync() || file.lengthSync() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }

  return target;
}

/// Converts PCM16 LE microphone bytes to normalized float32 for sherpa_onnx.
Float32List pcm16BytesToFloat32(Uint8List bytes, [Endian endian = Endian.little]) {
  final samples = Float32List(bytes.length ~/ 2);
  final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

  for (var i = 0; i < bytes.length; i += 2) {
    samples[i ~/ 2] = data.getInt16(i, endian) / 32768.0;
  }

  return samples;
}
