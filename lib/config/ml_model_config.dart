import 'dart:io';

/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  static const audioSampleRate = 16000;

  /// Trailing silence (seconds) before a speech segment is committed.
  static const pauseSilenceSeconds = 1.2;

  /// Minimum PCM bytes before saving a conversation segment (~0.8s at 16kHz).
  static const minSegmentPcmBytes = 25600;

  /// Lower threshold when flushing the final open buffer on pause/stop.
  static const minFinishSegmentPcmBytes = 9600;

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
  static const summaryContextSize = 4096;
}
