import 'package:whisper_ggml/whisper_ggml.dart';

/// On-device speech-to-text using OpenAI Whisper via [whisper_ggml].
class WhisperService {
  WhisperService({
    WhisperModel model = WhisperModel.base,
    WhisperController? controller,
  })  : _model = model,
        _controller = controller ?? WhisperController();

  final WhisperModel _model;
  final WhisperController _controller;

  /// Transcribe a 16 kHz WAV file at [audioPath].
  Future<String> transcribeFile(
    String audioPath, {
    String language = 'auto',
  }) async {
    await _controller.downloadModel(_model);

    final result = await _controller.transcribe(
      model: _model,
      audioPath: audioPath,
      lang: language,
    );

    final text = result?.transcription.text.trim() ?? '';
    if (text.isEmpty) {
      throw Exception('Transcription failed');
    }
    return text;
  }
}
