import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../config/ml_model_config.dart';
import '../util/asr_text_util.dart';

/// Offline streaming ASR via [sherpa_onnx] (Zipformer model).
///
/// On first launch, copies model files from the asset bundle to the app's
/// data directory. If assets are missing, falls back to HTTP download from
/// HuggingFace.
class SherpaOnnxService {
  /// Called while model files are downloading (HTTP fallback only).
  void Function(String file, int received, int total)? onDownloadProgress;

  OnlineRecognizer? _recognizer;
  bool _modelReady = false;
  bool _disposed = false;
  Future<void>? _loading;

  static bool _bindingsInitialized = false;

  Future<void> ensureModelReady() async {
    if (_disposed) {
      throw StateError('SherpaOnnxService has been disposed');
    }
    // Stay loaded across captioning sessions — recreating OnlineRecognizer on
    // every Start re-reads ~70MB+ of ONNX and stalls the waveform 1–2s.
    if (_modelReady) return;
    return _loading ??= _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      if (!_bindingsInitialized) {
        initBindings();
        _bindingsInitialized = true;
      }

      final modelDir = await _modelDirectory();
      await _ensureModelFiles(modelDir);

      final config = OnlineRecognizerConfig(
        feat: const FeatureConfig(sampleRate: 16000, featureDim: 80),
        model: OnlineModelConfig(
          transducer: OnlineTransducerModelConfig(
            encoder: '${modelDir.path}/${MlModelConfig.asrEncoderFile}',
            decoder: '${modelDir.path}/${MlModelConfig.asrDecoderFile}',
            joiner: '${modelDir.path}/${MlModelConfig.asrJoinerFile}',
          ),
          tokens: '${modelDir.path}/${MlModelConfig.asrTokensFile}',
          modelType: MlModelConfig.asrModelType,
          numThreads: MlModelConfig.asrThreads,
          provider: 'cpu',
          debug: kDebugMode,
        ),
        decodingMethod: 'greedy_search',
        maxActivePaths: 4,
        enableEndpoint: true,
        rule1MinTrailingSilence: 1.5,
        rule2MinTrailingSilence: 0.8,
        rule3MinUtteranceLength: 15.0,
      );

      final recognizer = OnlineRecognizer(config);
      if (_disposed) {
        recognizer.free();
        throw StateError('SherpaOnnxService has been disposed');
      }
      _recognizer = recognizer;
      _modelReady = true;
      debugPrint('[SherpaOnnx] model ready at ${modelDir.path}');
    } catch (error, stackTrace) {
      _recognizer = null;
      _modelReady = false;
      debugPrint('[SherpaOnnx] model load failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    } finally {
      _loading = null;
    }
  }

  Future<Directory> _modelDirectory() async {
    final dir = await getApplicationSupportDirectory();
    return Directory('${dir.path}/${MlModelConfig.asrModelId}');
  }

  Future<void> _ensureModelFiles(Directory modelDir) async {
    const files = [
      (MlModelConfig.asrEncoderFile, MlModelConfig.asrEncoderMinBytes),
      (MlModelConfig.asrDecoderFile, MlModelConfig.asrDecoderMinBytes),
      (MlModelConfig.asrJoinerFile, MlModelConfig.asrJoinerMinBytes),
      (MlModelConfig.asrTokensFile, MlModelConfig.asrTokensMinBytes),
    ];

    var allValid = true;
    for (final (file, minSize) in files) {
      final target = File('${modelDir.path}/$file');
      if (!await target.exists() || await target.length() < minSize) {
        allValid = false;
        break;
      }
    }
    if (allValid) return;

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    final copied = await _tryCopyFromAssets(modelDir);
    if (copied) return;

    debugPrint('[SherpaOnnx] assets not found, downloading from HuggingFace');
    await _downloadAllFiles(modelDir);
  }

  Future<bool> _tryCopyFromAssets(Directory modelDir) async {
    const assetDir = MlModelConfig.asrModelAssetDir;

    const files = [
      (MlModelConfig.asrEncoderFile, MlModelConfig.asrEncoderMinBytes),
      (MlModelConfig.asrDecoderFile, MlModelConfig.asrDecoderMinBytes),
      (MlModelConfig.asrJoinerFile, MlModelConfig.asrJoinerMinBytes),
      (MlModelConfig.asrTokensFile, MlModelConfig.asrTokensMinBytes),
    ];

    for (final (file, minSize) in files) {
      final assetKey = '$assetDir/$file';
      try {
        final data = await rootBundle.load(assetKey);
        if (data.lengthInBytes < minSize) {
          debugPrint(
            '[SherpaOnnx] asset too small (likely LFS pointer): $assetKey '
            '(${data.lengthInBytes} < $minSize bytes)',
          );
          return false;
        }
        final target = File('${modelDir.path}/$file');
        await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
        debugPrint('[SherpaOnnx] copied from assets: $file');
      } catch (_) {
        debugPrint('[SherpaOnnx] asset not found: $assetKey');
        return false;
      }
    }

    return true;
  }

  Future<void> _downloadAllFiles(Directory modelDir) async {
    const files = [
      (
        MlModelConfig.asrEncoderFile,
        MlModelConfig.asrEncoderMinBytes,
        MlModelConfig.asrEncoderBytes,
      ),
      (
        MlModelConfig.asrDecoderFile,
        MlModelConfig.asrDecoderMinBytes,
        MlModelConfig.asrDecoderBytes,
      ),
      (
        MlModelConfig.asrJoinerFile,
        MlModelConfig.asrJoinerMinBytes,
        MlModelConfig.asrJoinerBytes,
      ),
      (
        MlModelConfig.asrTokensFile,
        MlModelConfig.asrTokensMinBytes,
        MlModelConfig.asrTokensBytes,
      ),
    ];

    final pending = <(String, int, int)>[];
    for (final entry in files) {
      final target = File('${modelDir.path}/${entry.$1}');
      if (await target.exists() && await target.length() >= entry.$2) {
        continue;
      }
      pending.add(entry);
    }
    if (pending.isEmpty) return;

    // Progress is reported across every file that still needs downloading, so
    // the UI sees a single 0 → 100% run instead of one run per file.
    final totalBytes = pending.fold<int>(0, (sum, entry) => sum + entry.$3);
    var completedBytes = 0;

    for (final (file, minSize, expectedBytes) in pending) {
      final target = File('${modelDir.path}/$file');
      await _downloadFile(
        file,
        target,
        minSize,
        onBytes: (received) {
          onDownloadProgress?.call(file, completedBytes + received, totalBytes);
        },
      );
      completedBytes += expectedBytes;
      onDownloadProgress?.call(file, completedBytes, totalBytes);
    }
  }

  Future<void> _downloadFile(
    String fileName,
    File target,
    int minSize, {
    required void Function(int received) onBytes,
  }) async {
    const maxRetries = 3;
    const initialDelay = Duration(seconds: 2);
    final partFile = File('${target.path}.part');

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _downloadFileOnce(fileName, target, partFile, minSize, onBytes);
        return;
      } catch (e) {
        await _deleteIfExists(partFile);
        if (attempt == maxRetries) rethrow;
        final delay = initialDelay * attempt;
        debugPrint(
          '[SherpaOnnx] download attempt $attempt failed for $fileName, '
          'retrying in ${delay.inSeconds}s: $e',
        );
        await Future.delayed(delay);
      }
    }
  }

  Future<void> _downloadFileOnce(
    String fileName,
    File target,
    File partFile,
    int minSize,
    void Function(int received) onBytes,
  ) async {
    final url = Uri.parse('${MlModelConfig.hfBase}/$fileName');
    debugPrint('[SherpaOnnx] downloading $fileName from $url');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 300);

    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download $fileName: HTTP ${response.statusCode}',
        );
      }

      final total = response.contentLength;
      await _deleteIfExists(partFile);
      sink = partFile.openWrite();
      var received = 0;

      try {
        await for (final chunk in response) {
          received += chunk.length;
          onBytes(received);
          sink.add(chunk);
        }

        await sink.flush();
      } finally {
        await sink.close();
        sink = null;
      }

      final length = await partFile.length();
      if (length < minSize) {
        throw HttpException(
          'Downloaded $fileName is too small ($length < $minSize bytes)',
        );
      }
      if (total > 0 && length != total) {
        throw HttpException(
          'Downloaded $fileName size mismatch ($length != $total bytes)',
        );
      }
      if (length != received) {
        throw HttpException(
          'Downloaded $fileName write mismatch ($length != $received bytes)',
        );
      }

      await _deleteIfExists(target);
      await partFile.rename(target.path);

      debugPrint('[SherpaOnnx] downloaded $fileName ($received bytes)');
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  OnlineStream createStream() {
    _ensureReady();
    return _recognizer!.createStream();
  }

  void acceptWaveform(OnlineStream stream, Float32List samples) {
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
  }

  String decodeAndGetText(OnlineStream stream) {
    while (_recognizer!.isReady(stream)) {
      _recognizer!.decode(stream);
    }
    final result = _recognizer!.getResult(stream);
    return formatAsrText(result.text);
  }

  bool isEndpoint(OnlineStream stream) {
    return _recognizer!.isEndpoint(stream);
  }

  String finalizeStream(OnlineStream stream) {
    return finalizeStreamResult(stream).text;
  }

  /// Like [finalizeStream], but keeps token timestamps for splitting text
  /// at a mid-utterance speaker-change cut.
  AsrUtteranceResult finalizeStreamResult(OnlineStream stream) {
    while (_recognizer!.isReady(stream)) {
    _recognizer!.decode(stream);
    }
    final result = _recognizer!.getResult(stream);
    _recognizer!.reset(stream);
    return AsrUtteranceResult(
      text: formatAsrText(result.text),
      tokens: List<String>.from(result.tokens),
      timestamps: List<double>.from(result.timestamps),
    );
  }

  void _ensureReady() {
    if (_disposed) {
      throw StateError('SherpaOnnxService has been disposed');
    }
    if (!_modelReady || _recognizer == null) {
      throw StateError('SherpaOnnx model is not ready');
    }
  }

  bool get isModelReady => _modelReady;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _recognizer?.free();
    _recognizer = null;
    _modelReady = false;
    _loading = null;
  }
}

/// Streaming ASR result with optional per-token timestamps (seconds from
/// utterance start), used to split text at a mid-utterance speaker cut.
class AsrUtteranceResult {
  const AsrUtteranceResult({
    required this.text,
    this.tokens = const [],
    this.timestamps = const [],
  });

  final String text;
  final List<String> tokens;
  final List<double> timestamps;
}
