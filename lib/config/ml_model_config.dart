/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  static const audioSampleRate = 16000;

  /// Trailing silence (seconds) before a speech segment is committed.
  static const pauseSilenceSeconds = 0.6;

  /// Silence gap (ms) between segment commits that triggers a new paragraph.
  static const paragraphBreakMs = 1500;

  /// Maximum segment duration (seconds) — commit even without silence.
  static const maxSegmentSeconds = 8.0;

  /// Minimum PCM bytes before saving a conversation segment (~0.8s at 16kHz).
  static const minSegmentPcmBytes = 25600;

  /// Lower threshold when flushing the final open buffer on pause/stop.
  static const minFinishSegmentPcmBytes = 9600;

  /// PCM bytes per second at 16kHz 16-bit mono.
  static const pcmBytesPerSecond = audioSampleRate * 2;

  /// Offline segment transcription via [whisper_kit] (whisper.cpp).
  static const whisperModelName = 'tiny';
  static const whisperLanguage = 'en';
  static const whisperThreads = 2;

  /// Summarization: Qwen2.5-0.5B via flutter_llama.
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryContextSize = 4096;
}
