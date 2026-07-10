import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/ml_model_config.dart';
import '../util/logger/app_logger.dart';
import 'summary_prompt.dart';

/// Thrown when on-device summarization fails in a recoverable way.
class LlamaServiceException implements Exception {
  LlamaServiceException(
    this.message, {
    this.cause,
    this.isResourceLimit = false,
  });

  final String message;
  final Object? cause;
  final bool isResourceLimit;

  @override
  String toString() => message;
}

/// On-device summarization via [flutter_llama] + bundled Qwen2.5-0.5B.
class LlamaService {
  LlamaService({FlutterLlama? llama}) : _llama = llama ?? FlutterLlama.instance;

  final FlutterLlama _llama;
  static const MethodChannel _assetChannel =
      MethodChannel('clearhear/model_assets');

  bool get isModelLoaded => _llama.isModelLoaded;

  /// Load the bundled Qwen2.5-0.5B GGUF from app assets into a local file,
  /// then open it with llama.cpp.
  Future<bool> loadDefaultModel({
    required void Function(dynamic progress) onProgress,
  }) {
    return loadBundledModel(onProgress: onProgress);
  }

  /// Load the bundled Qwen2.5-0.5B GGUF from app assets into a local file,
  /// then open it with llama.cpp.
  Future<bool> loadBundledModel({
    required void Function(dynamic progress) onProgress,
  }) async {
    try {
      final modelPath = await _ensureBundledModelCopied(onProgress: onProgress);
      return loadModel(modelPath);
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'LlamaService',
      );
      return false;
    }
  }

  Future<String> _ensureBundledModelCopied({
    required void Function(dynamic progress) onProgress,
  }) async {
    final bundlePath = await _directBundledModelPath();
    if (bundlePath != null) {
      onProgress(1.0);
      return bundlePath;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(documentsDir.path, 'models'));
    await modelDir.create(recursive: true);

    final targetPath = p.join(modelDir.path, MlModelConfig.summaryModelFile);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      if (await _isValidGgufFile(targetFile)) {
        onProgress(1.0);
        return targetPath;
      }
      await targetFile.delete();
    }

    final copied = await _copyBundledAssetToFile(
      assetPath: MlModelConfig.summaryModelAssetPath,
      targetPath: targetPath,
    );
    if (!copied) {
      throw StateError(
        'Unable to copy bundled summary model to local storage.',
      );
    }

    final copiedFile = File(targetPath);
    if (!await _isValidGgufFile(copiedFile)) {
      await copiedFile.delete();
      throw StateError(_invalidModelMessage);
    }

    onProgress(1.0);
    return targetPath;
  }

  static const _ggufMagic = <int>[0x47, 0x47, 0x55, 0x46]; // "GGUF"
  static const _invalidModelMessage =
      'Summary model asset is missing or invalid. '
      'Run "git lfs pull" (or download the GGUF into assets/models/) '
      'then rebuild the app.';

  Future<bool> _isValidGgufFile(File file) async {
    if (!await file.exists()) return false;
    if (await file.length() < MlModelConfig.summaryModelMinBytes) return false;

    final handle = await file.open();
    try {
      final bytes = await handle.read(4);
      if (bytes.length < 4) return false;
      for (var i = 0; i < 4; i++) {
        if (bytes[i] != _ggufMagic[i]) return false;
      }
      return true;
    } finally {
      await handle.close();
    }
  }

  Future<String?> _directBundledModelPath() async {
    if (Platform.isAndroid) {
      final bundleDir = await _assetBundleDirectory();
      if (bundleDir == null) return null;
      final bundleFile = File(
        p.join(bundleDir, MlModelConfig.summaryModelAssetPath),
      );
      if (await _isValidGgufFile(bundleFile)) {
        return bundleFile.path;
      }
      return null;
    }

    return null;
  }

  Future<String?> _assetBundleDirectory() async {
    try {
      final result = await _assetChannel.invokeMethod<String>(
        'getAssetBundleDir',
      );
      return result?.trim().isEmpty == true ? null : result;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> _copyBundledAssetToFile({
    required String assetPath,
    required String targetPath,
  }) async {
    if (!Platform.isAndroid) {
      final byteData = await rootBundle.load(assetPath);
      await File(targetPath)
          .writeAsBytes(Uint8List.sublistView(byteData), flush: true);
      return true;
    }

    try {
      final result = await _assetChannel.invokeMethod<bool>(
        'copyAssetToFile',
        {
          'assetPath': assetPath,
          'targetPath': targetPath,
        },
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Load a GGUF model from [modelPath].
  Future<bool> loadModel(String modelPath) async {
    try {
      return await _llama.loadModel(
        LlamaConfig(
          modelPath: modelPath,
          nThreads: MlModelConfig.summaryThreads,
          nGpuLayers: 0,
          contextSize: MlModelConfig.summaryContextSize,
          batchSize: MlModelConfig.summaryBatchSize,
          useGpu: false,
          verbose: false,
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'LlamaService',
      );
      return false;
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'LlamaService',
      );
      return false;
    }
  }

  /// Summarize [transcript] into plain text with no markdown.
  Future<String> summarize(String transcript) async {
    try {
      _ensureModelLoaded();

      final response = await _llama.generate(
        GenerationParams(
          prompt: buildBoundedSummaryPrompt(transcript),
          maxTokens: MlModelConfig.summaryMaxTokens,
          temperature: 0.2,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
        ),
      );
      return _sanitizeOutput(response.text);
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'LlamaService',
      );
      throw _toSummaryException(error);
    }
  }

  /// Stream summary tokens as they are generated.
  Stream<String> summarizeStream(String transcript) async* {
    try {
      _ensureModelLoaded();

      yield* _llama.generateStream(
        GenerationParams(
          prompt: buildBoundedSummaryPrompt(transcript),
          maxTokens: MlModelConfig.summaryMaxTokens,
          temperature: 0.2,
          topP: 0.9,
          topK: 40,
          repeatPenalty: 1.1,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'LlamaService',
      );
      throw _toSummaryException(error);
    }
  }

  String _sanitizeOutput(String text) {
    final paragraphs = text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n{2,}'))
        .map((paragraph) => paragraph
            .split('\n')
            .map((line) => line
                .replaceAll(RegExp(r'^\s*#{1,6}\s*'), '')
                .replaceAll(RegExp(r'^\s*[-*•]\s*'), '')
                .replaceAll(RegExp(r'^\s*\d+[.)]\s*'), '')
                .replaceAll(RegExp(r'[*_`]+'), '')
                .trim())
            .where((line) => line.isNotEmpty)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();

    final normalized = paragraphs.join('\n\n').trim();
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length <= 250) return normalized;
    return words.take(250).join(' ');
  }

  void _ensureModelLoaded() {
    if (!isModelLoaded) {
      throw LlamaServiceException(
        'Llama model is not loaded. Call loadModel() first.',
      );
    }
  }

  LlamaServiceException _toSummaryException(Object error) {
    if (error is LlamaServiceException) return error;

    if (error is PlatformException) {
      final message = error.message?.trim();
      return LlamaServiceException(
        message?.isNotEmpty == true
            ? message!
            : 'Summary generation failed.',
        cause: error,
        isResourceLimit: looksLikeResourceLimit(error),
      );
    }

    return LlamaServiceException(
      'Summary generation failed.',
      cause: error,
      isResourceLimit: looksLikeResourceLimit(error),
    );
  }

  static bool looksLikeResourceLimit(Object error) {
    if (error is LlamaServiceException) return error.isResourceLimit;

    final text = switch (error) {
      PlatformException(:final code, :final message) =>
        '$code ${message ?? ''}'.toLowerCase(),
      _ => error.toString().toLowerCase(),
    };

    const resourcePhrases = [
      'out of memory',
      'ran out of memory',
      'not enough memory',
      'insufficient memory',
      'failed to allocate',
      'could not allocate',
      'unable to allocate',
      'context window',
      'context size',
      'exceeds context',
      'exceeds the context',
      'resource limit',
      'insufficient resources',
      'kv cache',
      'llama_decode',
      'exceeds batch',
      'n_batch',
    ];

    return resourcePhrases.any(text.contains);
  }

  Future<void> unloadModel() async {
    try {
      await _llama.unloadModel();
    } catch (error, stackTrace) {
      AppLogger.error(
        error: error,
        stackTrace: stackTrace,
        tag: 'LlamaService',
      );
    }
  }
}
