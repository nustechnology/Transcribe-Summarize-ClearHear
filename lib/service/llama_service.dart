import 'package:flutter_llama/flutter_llama.dart';

/// On-device LLM inference for summarization via [flutter_llama].
class LlamaService {
  LlamaService({FlutterLlama? llama}) : _llama = llama ?? FlutterLlama.instance;

  final FlutterLlama _llama;

  bool get isModelLoaded => _llama.isModelLoaded;

  /// Download (if needed) and load the recommended Braindler preset.
  Future<bool> loadDefaultModel({
    required DownloadProgressCallback onProgress,
  }) {
    return _llama.loadPresetModel(
      preset: PresetModels.braindlerQ4K,
      onProgress: onProgress,
    );
  }

  /// Load a GGUF model from [modelPath].
  Future<bool> loadModel(String modelPath) {
    return _llama.loadModel(
      LlamaConfig(
        modelPath: modelPath,
        nThreads: 4,
        nGpuLayers: -1,
        contextSize: 2048,
        useGpu: true,
      ),
    );
  }

  /// Summarize [transcript] with a short bullet-point prompt.
  Future<String> summarize(String transcript) async {
    final response = await _llama.generate(
      GenerationParams(
        prompt: '''
Summarize the following transcript in 3-5 concise bullet points:

$transcript
''',
        maxTokens: 512,
        temperature: 0.7,
      ),
    );
    return response.text;
  }

  Future<void> unloadModel() => _llama.unloadModel();
}
