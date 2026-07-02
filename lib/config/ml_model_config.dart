import 'package:whisper_ggml/whisper_ggml.dart';

/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  /// Captioning: Whisper via [whisper_ggml]. `tiny` is fastest on-device.
  /// Use `base` or `small` if you need higher accuracy.
  static const liveWhisperModel = WhisperModel.tiny;

  /// Whisper language code (`en`, `vi`, …).
  static const whisperLanguage = 'en';

  /// Summarization: Qwen2.5-0.5B via flutter_llama (temporarily disabled).
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryContextSize = 4096;
}
