import 'dart:io';
import 'package:flutter/foundation.dart';

/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  static const audioSampleRate = 16000;

  /// Minimum PCM bytes before saving a conversation segment (~0.8s at 16kHz).
  static const minSegmentPcmBytes = 25600;

  /// How often the in-progress utterance buffer is re-decoded for partial text.
  static const partialRefreshIntervalMs = 400;

  /// Minimum PCM bytes before attempting a partial re-decode (~0.3s at 16kHz).
  static const minPartialPcmBytes = 9600;

  /// Offline segment transcription via [whisper_kit] (whisper.cpp).
  static const whisperModelName = 'tiny';
  static const whisperLanguage = 'en';
  static const whisperThreads = 2;

  /// Use a single worker thread on Android to avoid whisper.cpp crashes on emulators.
  static int get whisperThreadsForPlatform =>
      Platform.isAndroid ? 1 : whisperThreads;

  /// Summarization: Qwen2.5-0.5B via flutter_llama.
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryModelAssetPath =
      'assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  /// Expected on-disk size for the bundled Q4_K_M 0.5B GGUF (~469 MB).
  static const summaryModelExpectedBytes = 491400032;
  /// Reject LFS pointers / truncated copies well below the real model size.
  static const summaryModelMinBytes = 100 * 1024 * 1024;
  static const summaryThreads = 2;

  /// llama.cpp context window. Lower in debug to reduce KV-cache RAM on emulators.
  static int get summaryContextSize => kDebugMode ? 1024 : 2048;

  /// flutter_llama sends the full prompt in a single llama_decode batch.
  /// llama.cpp aborts when prompt tokens exceed n_batch.
  static int get summaryBatchSize => summaryContextSize;

  static int get summaryMaxTokens => kDebugMode ? 128 : 192;

  /// Transcript chars fed into the prompt (before tokenization).
  static int get summaryTranscriptCharLimit => kDebugMode ? 600 : 1000;

  /// Reserved for system instructions + chat template outside the transcript.
  static const summaryPromptOverheadTokens = 220;

  /// Silero VAD (v4/legacy) ONNX model, bundled so voice activity detection
  /// works fully offline instead of fetching it from the `vad` package's CDN.
  static const vadModelAssetBasePath = 'assets/models/';
}
