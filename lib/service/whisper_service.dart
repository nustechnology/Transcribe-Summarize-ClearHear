import 'package:whisper_ggml/whisper_ggml.dart';

import '../config/ml_model_config.dart';

/// On-device speech-to-text using OpenAI Whisper via [whisper_ggml].
class WhisperService {
  WhisperService({
    WhisperModel? model,
    WhisperController? controller,
  })  : _model = model ?? MlModelConfig.liveWhisperModel,
        _controller = controller ?? WhisperController();

  final WhisperModel _model;
  final WhisperController _controller;

  bool _modelReady = false;
  Future<void>? _loadingFuture;

  bool get isModelReady => _modelReady;

  bool get isModelLoading => _loadingFuture != null && !_modelReady;

  Future<void> ensureModelReady() {
    if (_modelReady) return Future.value();
    return _loadingFuture ??= _downloadModel();
  }

  Future<void> _downloadModel() async {
    try {
      await _controller.downloadModel(_model);
      _modelReady = true;
    } finally {
      _loadingFuture = null;
    }
  }

  /// Transcribe a 16 kHz WAV file at [audioPath].
  Future<String> transcribeFile(
    String audioPath, {
    String language = 'auto',
  }) async {
    final text = await _transcribe(audioPath, language: language);
    if (text.isEmpty) {
      throw Exception('Transcription failed');
    }
    return text;
  }

  /// Transcribe a chunk; returns empty string when nothing was detected.
  Future<String> transcribeChunk(
    String audioPath, {
    String language = 'auto',
  }) {
    return _transcribe(audioPath, language: language);
  }

  Future<String> _transcribe(
    String audioPath, {
    required String language,
  }) async {
    await ensureModelReady();

    final result = await _controller.transcribe(
      model: _model,
      audioPath: audioPath,
      lang: language,
    );

    return result?.transcription.text.trim() ?? '';
  }
}
