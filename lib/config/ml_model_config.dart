import 'package:whisper_ggml/whisper_ggml.dart';

/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  /// Live captioning: Whisper via [whisper_ggml] (chunked while recording).
  static const liveWhisperModel = WhisperModel.tiny;

  /// First transcript attempt — shorter than [liveChunkInterval].
  static const liveInitialChunkDelay = Duration(milliseconds: 1500);

  /// How often to rotate the recorder (decoupled from Whisper inference time).
  static const liveChunkInterval = Duration(seconds: 2);

  /// Summarization: Qwen2.5-0.5B via [flutter_llama].
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryContextSize = 4096;
}
