import 'dart:io';
import 'package:flutter/foundation.dart';

/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  static const audioSampleRate = 16000;

  /// Sherpa-onnx streaming ASR model.
  static const asrModelId = 'sherpa-onnx-streaming-zipformer-en-2023-06-26';
  static const asrModelType = 'zipformer2';

  /// Asset bundle path for the model directory.
  static const asrModelAssetDir = 'assets/models/$asrModelId';

  /// HuggingFace CDN paths for individual model files.
  static const hfBase =
      'https://huggingface.co/csukuangfj/$asrModelId/resolve/main';
  static const asrEncoderFile =
      'encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx';
  static const asrDecoderFile =
      'decoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx';
  static const asrJoinerFile =
      'joiner-epoch-99-avg-1-chunk-16-left-64.int8.onnx';
  static const asrTokensFile = 'tokens.txt';

  /// Minimum file size in bytes to consider a model file valid.
  /// Actual sizes: encoder ~71 MB, decoder ~1.3 MB, joiner ~259 KB, tokens ~5 KB.
  static const asrEncoderMinBytes = 50 * 1024 * 1024;
  static const asrDecoderMinBytes = 500 * 1024;
  static const asrJoinerMinBytes = 100 * 1024;
  static const asrTokensMinBytes = 1024;

  /// Download size of each model file, used to report one combined progress
  /// across all files instead of restarting the bar per file.
  /// Measured sizes: encoder 71,082,637 B · decoder 1,307,236 B ·
  /// joiner 259,335 B · tokens 5,048 B (total ≈ 0.3% below the values below).
  static const asrEncoderBytes = 68 * 1024 * 1024;
  static const asrDecoderBytes = 1277 * 1024;
  static const asrJoinerBytes = 253 * 1024;
  static const asrTokensBytes = 5 * 1024;

  /// Number of threads for sherpa-onnx decoding.
  static int get asrThreads => Platform.isAndroid ? 1 : 2;

  /// Summarization: Qwen2.5-0.5B via flutter_llama.
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryModelAssetPath =
      'assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryModelExpectedBytes = 491400032;
  static const summaryModelMinBytes = 100 * 1024 * 1024;
  static const summaryThreads = 2;

  static int get summaryContextSize => kDebugMode ? 1024 : 2048;
  static int get summaryBatchSize => summaryContextSize;
  static int get summaryMaxTokens => kDebugMode ? 128 : 192;
  static int get summaryTranscriptCharLimit => kDebugMode ? 600 : 1000;
  static const summaryPromptOverheadTokens = 220;
}
