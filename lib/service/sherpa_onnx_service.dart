import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../config/ml_model_config.dart';
import '../utils/asr_text_util.dart';
import '../utils/sherpa_audio_util.dart';

/// On-device streaming speech recognition via [sherpa_onnx].
class SherpaOnnxService {
  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  String _committedText = '';
  bool _bindingsInitialized = false;

  Future<void> ensureModelReady() async {
    if (_recognizer != null) return;

    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }

    final modelDir = MlModelConfig.sherpaStreamingModelDir;
    final pauseSilence = MlModelConfig.sherpaPauseSilenceSeconds;
    final modelConfig = sherpa.OnlineModelConfig(
      transducer: sherpa.OnlineTransducerModelConfig(
        encoder: await copySherpaAssetFile(MlModelConfig.sherpaEncoderAsset),
        decoder: await copySherpaAssetFile(MlModelConfig.sherpaDecoderAsset),
        joiner: await copySherpaAssetFile(MlModelConfig.sherpaJoinerAsset),
      ),
      tokens: await copySherpaAssetFile(MlModelConfig.sherpaTokensAsset),
      modelType: MlModelConfig.sherpaModelType,
      modelingUnit: MlModelConfig.sherpaModelingUnit,
      bpeVocab: await copySherpaAssetFile(MlModelConfig.sherpaBpeVocabAsset),
      debug: false,
    );

    _recognizer = sherpa.OnlineRecognizer(
      sherpa.OnlineRecognizerConfig(
        model: modelConfig,
        ruleFsts: '',
        enableEndpoint: true,
        rule1MinTrailingSilence: pauseSilence + 0.6,
        rule2MinTrailingSilence: pauseSilence,
      ),
    );

    debugPrint('[Sherpa] multilingual streaming recognizer ready ($modelDir)');
  }

  void startSession() {
    _committedText = '';
    _stream?.free();
    _stream = _recognizer?.createStream();
  }

  /// Feed one PCM chunk and return the caption text to display.
  String processPcmChunk(Uint8List pcmBytes) {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null || pcmBytes.isEmpty) {
      return _committedText;
    }

    stream.acceptWaveform(
      samples: pcm16BytesToFloat32(pcmBytes),
      sampleRate: MlModelConfig.sherpaSampleRate,
    );

    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    final partial = formatAsrText(recognizer.getResult(stream).text);
    if (recognizer.isEndpoint(stream)) {
      if (partial.isNotEmpty) {
        _committedText = _appendLine(_committedText, partial);
        debugPrint('[Sherpa] pause detected, new line: $partial');
      }
      recognizer.reset(stream);
      return _committedText;
    }

    return _composeDisplay(_committedText, partial);
  }

  String finishSession() {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) {
      return _committedText.trim();
    }

    final partial = formatAsrText(recognizer.getResult(stream).text);
    if (partial.isNotEmpty) {
      _committedText = _appendLine(_committedText, partial);
    }

    return _committedText.trim();
  }

  void dispose() {
    _stream?.free();
    _stream = null;
    _recognizer?.free();
    _recognizer = null;
    _committedText = '';
  }

  /// Commits a finished utterance as a new line after a speech pause.
  String _appendLine(String committed, String line) {
    final previous = committed.trimRight();
    final next = line.trim();
    if (next.isEmpty) return previous;
    if (previous.isEmpty) return next;
    return '$previous\n$next';
  }

  /// Shows committed lines plus the in-progress utterance on the last line.
  String _composeDisplay(String committed, String partial) {
    final live = partial.trim();
    if (live.isEmpty) return committed;
    return _appendLine(committed, live);
  }
}
