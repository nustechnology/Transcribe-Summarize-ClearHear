/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  /// Streaming ASR via [sherpa_onnx].
  /// Supports Arabic, English, Indonesian, Japanese, Russian, Thai, Vietnamese, Chinese.
  static const sherpaStreamingModelDir =
      'assets/sherpa-onnx-streaming-zipformer-ar_en_id_ja_ru_th_vi_zh-2025-02-10';

  static const sherpaEncoderAsset =
      '$sherpaStreamingModelDir/encoder-epoch-75-avg-11-chunk-16-left-128.int8.onnx';

  static const sherpaDecoderAsset =
      '$sherpaStreamingModelDir/decoder-epoch-75-avg-11-chunk-16-left-128.onnx';

  static const sherpaJoinerAsset =
      '$sherpaStreamingModelDir/joiner-epoch-75-avg-11-chunk-16-left-128.int8.onnx';

  static const sherpaTokensAsset = '$sherpaStreamingModelDir/tokens.txt';

  static const sherpaBpeVocabAsset = '$sherpaStreamingModelDir/bpe.model';

  static const sherpaModelType = 'zipformer2';

  static const sherpaModelingUnit = 'bpe';

  static const sherpaSampleRate = 16000;

  /// Trailing silence (seconds) before Sherpa treats speech as a pause/new line.
  static const sherpaPauseSilenceSeconds = 1.2;

  /// Summarization: Qwen2.5-0.5B via flutter_llama (temporarily disabled).
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryContextSize = 4096;
}
