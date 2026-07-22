import 'dart:io';
import 'package:flutter/foundation.dart';

/// On-device ML stack for ClearHear.
abstract final class MlModelConfig {
  static const audioSampleRate = 16000;

  /// Sherpa-onnx streaming ASR model.
  static const asrModelId = 'sherpa-onnx-streaming-zipformer-en-2023-06-26';
  static const asrModelType = 'zipformer2';

  /// Asset bundle path for the model directory.
  static const asrModelAssetDir = 'assets/models/$asrModelId';

  /// HuggingFace CDN paths for individual model files.
  static const hfBase =
      'https://huggingface.co/csukuangfj/$asrModelId/resolve/main';
  static const asrEncoderFile =
      'encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx';
  static const asrDecoderFile =
      'decoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx';
  static const asrJoinerFile =
      'joiner-epoch-99-avg-1-chunk-16-left-64.int8.onnx';
  static const asrTokensFile = 'tokens.txt';

  /// Minimum file size in bytes to consider a model file valid.
  /// Actual sizes: encoder ~71 MB, decoder ~1.3 MB, joiner ~259 KB, tokens ~5 KB.
  static const asrEncoderMinBytes = 50 * 1024 * 1024;
  static const asrDecoderMinBytes = 500 * 1024;
  static const asrJoinerMinBytes = 100 * 1024;
  static const asrTokensMinBytes = 1024;

  /// Download size of each model file, used to report one combined progress
  /// across all files instead of restarting the bar per file.
  /// Measured sizes: encoder 71,082,637 B · decoder 1,307,236 B ·
  /// joiner 259,335 B · tokens 5,048 B (total ≈ 0.3% below the values below).
  static const asrEncoderBytes = 68 * 1024 * 1024;
  static const asrDecoderBytes = 1277 * 1024;
  static const asrJoinerBytes = 253 * 1024;
  static const asrTokensBytes = 5 * 1024;

  /// Number of threads for sherpa-onnx decoding.
  static int get asrThreads => Platform.isAndroid ? 1 : 2;

  /// Speaker diarization: per-utterance 3D-Speaker embedding + online
  /// nearest-speaker matching (see [SpeakerDiarizationService]).
  ///
  /// Segment boundaries come primarily from the ASR recognizer's endpoint
  /// detection (see [SherpaOnnxService.isEndpoint]). While an utterance is
  /// open, a rolling embedding probe can also force-cut on mid-utterance
  /// speaker changes that silence-based endpoints would miss.
  static const diarizationEmbeddingModelId = 'speaker-embedding-models';
  static const diarizationEmbeddingFile =
      '3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx';
  static const diarizationEmbeddingHfBase =
      'https://huggingface.co/csukuangfj/$diarizationEmbeddingModelId/resolve/main';
  // Actual size ~27 MB (28,281,164 bytes).
  static const diarizationEmbeddingMinBytes = 20 * 1024 * 1024;
  static const diarizationEmbeddingAssetDir =
      'assets/models/$diarizationEmbeddingModelId';

  static int get diarizationThreads => Platform.isAndroid ? 1 : 2;

  /// Cosine-similarity threshold for matching a segment's embedding to an
  /// already-known speaker in the current session. Below this, a new
  /// speaker is registered instead.
  ///
  /// History from real device logs (`[SpeakerDiarization] best match: ...
  /// score=...`), each fixing a concrete observed failure rather than
  /// guessing:
  /// - 0.5 and 0.3 (both matched via sherpa-onnx's native
  ///   `SpeakerEmbeddingManager`) over-split a 2-person conversation.
  /// - Switching to matching each speaker's individual stored samples
  ///   (max similarity, see [SpeakerDiarizationService]) instead of one
  ///   blended running-average embedding narrowed the worst false
  ///   negative from 0.183 to 0.297 at threshold 0.3.
  /// - Lowering to 0.28 wasn't enough: the next log showed the same
  ///   pattern again, now at 0.273 — specifically for a speaker's very
  ///   first profile (only 1–2 samples), which is less representative
  ///   than profiles that had already accumulated more samples (those
  ///   consistently scored 0.3–0.6 against themselves). Meanwhile
  ///   confirmed different-speaker scores have stayed in the ~0.07–0.13
  ///   range across both logs — a wide, consistent gap below any
  ///   observed genuine-match score. Lowered to 0.22, comfortably below
  ///   every genuine-match near-miss seen so far while staying well
  ///   above every impostor score seen so far.
  static const diarizationSpeakerMatchThreshold = 0.22;

  /// Minimum buffered audio (seconds) before computing a speaker embedding
  /// for early labeling / segment registration. Cam++ is usable from
  /// ~0.8s; kept at 1.0s for multi-speaker rapid turns so badges appear
  /// sooner without waiting a full 1.5s after every cut.
  static const diarizationMinSegmentSeconds = 1.0;

  /// How often to re-embed the trailing audio window while an utterance is
  /// still open, looking for a mid-utterance speaker change that ASR
  /// silence-endpointing would miss. Short interval so fast turn-taking
  /// (e.g. 4-person male/female conversation) is noticed quickly.
  static const diarizationChangeProbeIntervalSeconds = 0.35;

  /// Length of the trailing audio window used for speaker-change probes.
  /// Short enough to react to rapid turns; long enough for a usable
  /// Cam++ embedding (~0.8s lower bound).
  static const diarizationChangeWindowSeconds = 0.8;

  /// When probing for a speaker change, the pending speaker's cosine score
  /// must fall below this before an "unknown new voice" result is allowed
  /// to force-cut. Prevents same-speaker variance just under the match
  /// threshold from spawning spurious segments.
  static const diarizationSpeakerChangeRejectThreshold = 0.15;

  /// Minimum gap between the best (other) speaker score and the pending
  /// speaker's score before a different-known-speaker match force-cuts.
  static const diarizationSpeakerChangeMargin = 0.08;

  /// Gap at which a different-known-speaker match force-cuts on the first
  /// probe (no confirmation streak). Cross-gender switches often land here.
  static const diarizationSpeakerChangeStrongMargin = 0.15;

  /// Consecutive disagreeing probes required before force-cutting when the
  /// evidence is only moderate (not a [diarizationSpeakerChangeStrongMargin]
  /// hit), to ignore one-off noisy windows.
  static const diarizationSpeakerChangeConfirmCount = 2;

  /// Minimum RMS (float32, [-1,1]) for a probe/early-label window to be
  /// treated as speech. Quieter windows are skipped so silence/noise does
  /// not fake a speaker change.
  static const diarizationSpeechMinRms = 0.015;

  /// Summarization: Qwen2.5-0.5B via flutter_llama.
  static const summaryModelId = 'Qwen/Qwen2.5-0.5B-Instruct-GGUF';
  static const summaryModelFile = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryModelAssetPath =
      'assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const summaryModelExpectedBytes = 491400032;
  static const summaryModelMinBytes = 100 * 1024 * 1024;
  static const summaryThreads = 2;

  static int get summaryContextSize => kDebugMode ? 1024 : 2048;
  static int get summaryBatchSize => summaryContextSize;
  static int get summaryMaxTokens => kDebugMode ? 128 : 192;
  static int get summaryTranscriptCharLimit => kDebugMode ? 600 : 1000;
  static const summaryPromptOverheadTokens = 220;
}
