import 'package:flutter_llama/flutter_llama.dart';

import '../config/ml_model_config.dart';

/// On-device summarization via [flutter_llama] + Qwen2.5-0.5B.
class LlamaService {
  LlamaService({FlutterLlama? llama}) : _llama = llama ?? FlutterLlama.instance;

  final FlutterLlama _llama;

  bool get isModelLoaded => _llama.isModelLoaded;

  /// Download (if needed) and load Qwen2.5-0.5B-Instruct GGUF.
  Future<bool> loadDefaultModel({
    required void Function(dynamic progress) onProgress,
  }) async {
    final manager = ModelManager(
      modelId: MlModelConfig.summaryModelId,
      source: ModelSource.huggingFace,
      specificFile: MlModelConfig.summaryModelFile,
    );

    final modelPath = await manager.ensureModelLoaded(
      onProgress: (downloadProgress) => onProgress(downloadProgress),
    );

    return loadModel(modelPath);
  }

  /// Load a GGUF model from [modelPath].
  Future<bool> loadModel(String modelPath) async {
    return _llama.loadModel(
      LlamaConfig(
        modelPath: modelPath,
        nThreads: 4,
        nGpuLayers: -1,
        contextSize: MlModelConfig.summaryContextSize,
        useGpu: true,
      ),
    );
  }

  /// Summarize [transcript] with a short bullet-point prompt.
  Future<String> summarize(String transcript) async {
    _ensureModelLoaded();

    final response = await _llama.generate(
      GenerationParams(
        prompt: _summaryPrompt(transcript),
        maxTokens: 512,
        temperature: 0.7,
      ),
    );
    return response.text;
  }

  /// Stream summary tokens as they are generated.
  Stream<String> summarizeStream(String transcript) {
    _ensureModelLoaded();

    return _llama.generateStream(
      GenerationParams(
        prompt: _summaryPrompt(transcript),
        maxTokens: 512,
        temperature: 0.7,
      ),
    );
  }

  String _summaryPrompt(String transcript) {
    const imStart = '<|im_start|>';
    const imEnd = '<|im_end|>';

    return '${imStart}system\n'
        'You are a concise assistant. Summarize transcripts in 3-5 bullet points. '
        'Keep the total summary under 250 words.'
        '$imEnd\n'
        '${imStart}user\n'
        'Summarize the following transcript:\n\n'
        '$transcript'
        '$imEnd\n'
        '${imStart}assistant\n';
  }

  void _ensureModelLoaded() {
    if (!isModelLoaded) {
      throw StateError('Llama model is not loaded. Call loadModel() first.');
    }
  }

  Future<void> unloadModel() => _llama.unloadModel();
}
