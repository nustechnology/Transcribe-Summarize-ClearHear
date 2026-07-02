import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Transcribe a recording file produced by [AudioRecorderService].
  Future<String> transcribeRecording(
    String audioPath, {
    String? language,
  }) async {
    await ensureModelReady();

    final input = File(audioPath);
    if (!await input.exists()) {
      debugPrint('[Whisper] audio file missing: $audioPath');
      return '';
    }

    final size = await input.length();
    debugPrint('[Whisper] transcribing $size bytes at $audioPath');

    final result = await _controller.transcribe(
      model: _model,
      audioPath: audioPath,
      lang: language ?? MlModelConfig.whisperLanguage,
    );

    final text = result?.transcription.text.trim() ?? '';
    debugPrint('[Whisper] transcription: $text');
    return text;
  }

  /// Transcribe an audio file at [audioPath].
  Future<String> transcribeFile(
    String audioPath, {
    String? language,
  }) async {
    final text = await transcribeRecording(audioPath, language: language);
    if (text.isEmpty) {
      throw Exception('Transcription failed');
    }
    return text;
  }
}
