// import 'package:flutter_llama/flutter_llama.dart';

// import '../config/ml_model_config.dart';

/// On-device summarization via [flutter_llama] + Qwen2.5-0.5B.
/// Temporarily disabled — flutter_llama dependency is commented out.
class LlamaService {
  // LlamaService({FlutterLlama? llama}) : _llama = llama ?? FlutterLlama.instance;
  LlamaService();

  // final FlutterLlama _llama;

  // bool get isModelLoaded => _llama.isModelLoaded;
  bool get isModelLoaded => false;

  /// Download (if needed) and load Qwen2.5-0.5B-Instruct GGUF.
  Future<bool> loadDefaultModel({
    required void Function(dynamic progress) onProgress,
  }) async {
    // return _llama.loadModelWithAutoDownload(
    //   modelId: MlModelConfig.summaryModelId,
    //   source: ModelSource.huggingFace,
    //   specificFile: MlModelConfig.summaryModelFile,
    //   config: const LlamaConfig(
    //     modelPath: '',
    //     nThreads: 4,
    //     nGpuLayers: -1,
    //     contextSize: MlModelConfig.summaryContextSize,
    //     useGpu: true,
    //   ),
    //   onProgress: onProgress,
    // );
    return false;
  }

  /// Load a GGUF model from [modelPath].
  Future<bool> loadModel(String modelPath) async {
    // return _llama.loadModel(
    //   LlamaConfig(
    //     modelPath: modelPath,
    //     nThreads: 4,
    //     nGpuLayers: -1,
    //     contextSize: MlModelConfig.summaryContextSize,
    //     useGpu: true,
    //   ),
    // );
    return false;
  }

  /// Summarize [transcript] with a short bullet-point prompt.
  Future<String> summarize(String transcript) async {
    // final response = await _llama.generate(
    //   GenerationParams(
    //     prompt: _summaryPrompt(transcript),
    //     maxTokens: 512,
    //     temperature: 0.7,
    //   ),
    // );
    // return response.text;
    return '';
  }

  /// Stream summary tokens as they are generated.
  Stream<String> summarizeStream(String transcript) async* {
    // return _llama.generateStream(
    //   GenerationParams(
    //     prompt: _summaryPrompt(transcript),
    //     maxTokens: 512,
    //     temperature: 0.7,
    //   ),
    // );
    yield* const Stream.empty();
  }

  // String _summaryPrompt(String transcript) => '''
  // Summarize the following transcript in 3-5 concise bullet points:
  //
  // $transcript
  // ''';

  // Future<void> unloadModel() => _llama.unloadModel();
  Future<void> unloadModel() async {}
}
