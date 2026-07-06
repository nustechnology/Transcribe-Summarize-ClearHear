/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  static const audioSampleRate = 16000;

  /// Trailing silence (seconds) before a speech segment is committed.
  static const pauseSilenceSeconds = 1.2;

  /// Minimum PCM bytes before saving a conversation segment (~0.4s at 16kHz).
  static const minSegmentPcmBytes = 12800;

  /// Offline segment transcription via [whisper_kit] (whisper.cpp).
  static const whisperModelName = 'tiny';
  static const whisperLanguage = 'auto';
  static const whisperThreads = 2;

  /// Summarization: Qwen2.5-0.5B via flutter_llama.
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryContextSize = 4096;
}
