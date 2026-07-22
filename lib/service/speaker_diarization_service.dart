import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';

/// Result of a read-only speaker probe (see
/// [SpeakerDiarizationService.identifySpeaker]).
///
/// Unlike [SpeakerDiarizationService.labelSegment], probing never registers
/// new speakers or updates stored samples — it is safe to run repeatedly on
/// rolling windows mid-utterance.
class SpeakerProbeResult {
  const SpeakerProbeResult.matched(
    this.matchedLabel, {
    this.bestScore,
    this.pendingSpeakerScore,
  })  : isUnknownNewVoice = false,
        bestLabel = matchedLabel;

  const SpeakerProbeResult.unknownNewVoice({
    this.bestScore,
    this.bestLabel,
    this.pendingSpeakerScore,
  })  : matchedLabel = null,
        isUnknownNewVoice = true;

  const SpeakerProbeResult.inconclusive()
      : matchedLabel = null,
        isUnknownNewVoice = false,
        bestScore = null,
        bestLabel = null,
        pendingSpeakerScore = null;

  final String? matchedLabel;
  final bool isUnknownNewVoice;
  final double? bestScore;
  final String? bestLabel;

  /// Cosine similarity of the probe window to the pending utterance's
  /// speaker, when [SpeakerDiarizationService.identifySpeaker] was called
  /// with [relativeToLabel].
  final double? pendingSpeakerScore;
}

/// Live, per-utterance speaker labeling via [sherpa_onnx]'s speaker
/// embedding extractor.
///
/// Each finalized ASR segment's audio is turned into a fixed-size
/// embedding and matched against speakers seen earlier in the same
/// session (nearest-centroid by cosine similarity — implemented directly
/// here in Dart, see [_SpeakerProfile] and [_cosineSimilarity], rather
/// than via sherpa-onnx's own `SpeakerEmbeddingManager`, so the matching
/// logic and its actual similarity scores are fully visible and tunable;
/// the native manager's search gave no way to inspect why segments
/// weren't matching). A new "Speaker N" is registered the first time a
/// voice doesn't match anyone already known. This runs as soon as each
/// segment finishes, so labels appear live rather than only at the end of
/// a session.
///
/// The embedding model is copied from the asset bundle on first use (see
/// `tool/download_sherpa_onnx_model.sh`), falling back to an HTTP download
/// from HuggingFace if the assets are missing.
class SpeakerDiarizationService {
  SpeakerEmbeddingExtractor? _extractor;
  final List<_SpeakerProfile> _profiles = [];
  int _nextSpeakerIndex = 1;
  int _sessionGeneration = 0;

  bool _modelReady = false;
  bool _disposed = false;
  Future<void>? _loading;

  /// Number of speakers registered in the current session.
  int get knownSpeakerCount => _profiles.length;

  Future<void> ensureModelReady() async {
    if (_disposed) {
      throw StateError('SpeakerDiarizationService has been disposed');
    }
    // Once loaded, stay loaded: `labelSegment` calls this on every segment,
    // and re-running `_loadModel` would throw away the loaded extractor
    // and the profiles collected so far in the session.
    if (_modelReady) return;
    return _loading ??= _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final modelDir = await _modelDirectory();
      await _ensureModelFile(modelDir);

      final extractor = SpeakerEmbeddingExtractor(
        config: SpeakerEmbeddingExtractorConfig(
          model: '${modelDir.path}/${MlModelConfig.diarizationEmbeddingFile}',
          numThreads: MlModelConfig.diarizationThreads,
          debug: kDebugMode,
          provider: 'cpu',
        ),
      );

      if (_disposed) {
        extractor.free();
        throw StateError('SpeakerDiarizationService has been disposed');
      }
      _extractor = extractor;
      _modelReady = true;
      debugPrint('[SpeakerDiarization] model ready at ${modelDir.path}');
    } catch (error, stackTrace) {
      _extractor = null;
      _modelReady = false;
      debugPrint('[SpeakerDiarization] model load failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    } finally {
      _loading = null;
    }
  }

  Future<Directory> _modelDirectory() async {
    final dir = await getApplicationSupportDirectory();
    return Directory('${dir.path}/speaker-diarization-models');
  }

  Future<void> _ensureModelFile(Directory modelDir) async {
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    const file = MlModelConfig.diarizationEmbeddingFile;
    const minSize = MlModelConfig.diarizationEmbeddingMinBytes;
    final target = File('${modelDir.path}/$file');
    if (await target.exists() && await target.length() >= minSize) {
      return;
    }

    if (await _tryCopyFromAssets(file, minSize, target)) {
      return;
    }

    debugPrint(
      '[SpeakerDiarization] asset not found for $file, '
      'downloading from HuggingFace',
    );
    await _downloadFile(file, minSize, target);
  }

  Future<bool> _tryCopyFromAssets(
    String fileName,
    int minSize,
    File target,
  ) async {
    final assetKey = '${MlModelConfig.diarizationEmbeddingAssetDir}/$fileName';
    try {
      final data = await rootBundle.load(assetKey);
      if (data.lengthInBytes < minSize) {
        debugPrint(
          '[SpeakerDiarization] asset too small (likely LFS pointer): '
          '$assetKey (${data.lengthInBytes} < $minSize bytes)',
        );
        return false;
      }
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      debugPrint('[SpeakerDiarization] copied from assets: $fileName');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadFile(String fileName, int minSize, File target) async {
    const maxRetries = 3;
    const initialDelay = Duration(seconds: 2);
    final partFile = File('${target.path}.part');

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _downloadFileOnce(fileName, target, partFile, minSize);
        return;
      } catch (e) {
        await _deleteIfExists(partFile);
        if (attempt == maxRetries) rethrow;
        final delay = initialDelay * attempt;
        debugPrint(
          '[SpeakerDiarization] download attempt $attempt failed for '
          '$fileName, retrying in ${delay.inSeconds}s: $e',
        );
        await Future.delayed(delay);
      }
    }
  }

  Future<void> _downloadFileOnce(
    String fileName,
    File target,
    File partFile,
    int minSize,
  ) async {
    final url = Uri.parse('${MlModelConfig.diarizationEmbeddingHfBase}/$fileName');
    debugPrint('[SpeakerDiarization] downloading $fileName from $url');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 300);

    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to download $fileName: HTTP ${response.statusCode}',
        );
      }

      await _deleteIfExists(partFile);
      sink = partFile.openWrite();
      var received = 0;

      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
        sink = null;
      }

      final length = await partFile.length();
      if (length < minSize) {
        throw HttpException(
          'Downloaded $fileName is too small ($length < $minSize bytes)',
        );
      }

      await _deleteIfExists(target);
      await partFile.rename(target.path);

      debugPrint('[SpeakerDiarization] downloaded $fileName ($received bytes)');
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clears speaker state so a new live session starts with no known
  /// speakers (each session's "Speaker 1" is independent of past sessions).
  void resetSession() {
    _sessionGeneration++;
    _profiles.clear();
    _nextSpeakerIndex = 1;
  }

  /// Serializes profile mutations so concurrent [labelSegment] calls cannot
  /// both see an empty roster and each create "Speaker 1" / "Speaker 2".
  Future<void>? _labelLock;

  /// Extracts an embedding for [samples] (16 kHz mono) and matches it
  /// against speakers seen earlier this session by cosine similarity to
  /// each speaker's stored samples, registering a new speaker if none
  /// match closely enough. Returns null on failure or when the audio is
  /// too short for a reliable embedding — diarization is a best-effort
  /// enhancement over the transcript, not a hard requirement.
  Future<String?> labelSegment(Float32List samples) async {
    final previous = _labelLock;
    final gate = Completer<void>();
    _labelLock = gate.future;
    try {
      if (previous != null) await previous;
      return await _labelSegmentUnlocked(samples);
    } finally {
      gate.complete();
      if (identical(_labelLock, gate.future)) {
        _labelLock = null;
      }
    }
  }

  Future<String?> _labelSegmentUnlocked(Float32List samples) async {
    final generation = _sessionGeneration;
    try {
      final embedding = await _extractEmbedding(samples);
      if (embedding == null || generation != _sessionGeneration) return null;

      final match = _findBestMatch(embedding);
      debugPrint(
        '[SpeakerDiarization] best match: '
        '${match.profile?.label ?? "none"} '
        'score=${match.score.toStringAsFixed(3)} '
        'threshold=${MlModelConfig.diarizationSpeakerMatchThreshold} '
        '(${_profiles.length} known speakers)',
      );

      if (match.profile != null &&
          match.score >= MlModelConfig.diarizationSpeakerMatchThreshold) {
        match.profile!.addSample(embedding);
        return match.profile!.label;
      }

      final label = 'Speaker $_nextSpeakerIndex';
      _nextSpeakerIndex++;
      _profiles.add(_SpeakerProfile(label, embedding));
      return label;
    } catch (error, stackTrace) {
      debugPrint('[SpeakerDiarization] labelSegment failed: $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  /// Read-only probe: embeds [samples] and reports who it sounds like
  /// without mutating speaker profiles. Used for mid-utterance speaker-
  /// change detection.
  ///
  /// When [relativeToLabel] is set, [SpeakerProbeResult.pendingSpeakerScore]
  /// is filled with that speaker's similarity so callers can require a
  /// clear drop before force-cutting.
  ///
  /// [minSeconds] defaults to the change-probe window so rapid turn-taking
  /// can use shorter clips than early-label registration.
  Future<SpeakerProbeResult> identifySpeaker(
    Float32List samples, {
    String? relativeToLabel,
    double minSeconds = MlModelConfig.diarizationChangeWindowSeconds,
  }) async {
    try {
      if (_profiles.isEmpty) return const SpeakerProbeResult.inconclusive();

      final embedding = await _extractEmbedding(
        samples,
        minSeconds: minSeconds,
      );
      if (embedding == null) return const SpeakerProbeResult.inconclusive();

      final match = _findBestMatch(embedding);
      final pendingScore = relativeToLabel == null
          ? null
          : _scoreForLabel(embedding, relativeToLabel);

      debugPrint(
        '[SpeakerDiarization] probe: '
        '${match.profile?.label ?? "none"} '
        'score=${match.score.toStringAsFixed(3)} '
        'pending=${relativeToLabel ?? "-"} '
        'pendingScore=${pendingScore?.toStringAsFixed(3) ?? "-"} '
        'threshold=${MlModelConfig.diarizationSpeakerMatchThreshold} '
        '(${_profiles.length} known speakers)',
      );

      if (match.profile != null &&
          match.score >= MlModelConfig.diarizationSpeakerMatchThreshold) {
        return SpeakerProbeResult.matched(
          match.profile!.label,
          bestScore: match.score,
          pendingSpeakerScore: pendingScore,
        );
      }

      return SpeakerProbeResult.unknownNewVoice(
        bestScore: match.score >= 0 ? match.score : null,
        bestLabel: match.profile?.label,
        pendingSpeakerScore: pendingScore,
      );
    } catch (error, stackTrace) {
      debugPrint('[SpeakerDiarization] identifySpeaker failed: $error');
      debugPrint('$stackTrace');
      return const SpeakerProbeResult.inconclusive();
    }
  }

  /// Rebuilds speaker profiles from scratch using each segment's retained
  /// [ConversationSegment.audioSamples], then updates [speakerLabel] in
  /// chronological order. Improves labels after rapid live turns where early
  /// windows were mixed or too short.
  ///
  /// Yields to the event loop between segments so Flutter can paint frames
  /// (loading indicators, scrolling) instead of freezing the UI isolate on
  /// back-to-back Cam++ `compute` calls.
  Future<void> relabelSegments(List<ConversationSegment> segments) async {
    final withAudio = segments
        .where(
          (s) =>
              s.audioSamples != null &&
              s.audioSamples!.length >=
                  MlModelConfig.audioSampleRate *
                      MlModelConfig.diarizationMinSegmentSeconds,
        )
        .toList(growable: false);
    if (withAudio.isEmpty) return;

    resetSession();
    for (final segment in withAudio) {
      await Future<void>.delayed(Duration.zero);
      try {
        final label = await labelSegment(segment.audioSamples!);
        if (label != null) {
          segment.speakerLabel = label;
        }
      } catch (error, stackTrace) {
        debugPrint(
          '[SpeakerDiarization] relabel segment ${segment.id} failed: $error',
        );
        debugPrint('$stackTrace');
      }
    }
    debugPrint(
      '[SpeakerDiarization] relabeled ${withAudio.length} segments '
      '(${_profiles.length} speakers)',
    );
  }

  Future<Float32List?> _extractEmbedding(
    Float32List samples, {
    double minSeconds = MlModelConfig.diarizationMinSegmentSeconds,
  }) async {
    if (samples.length < MlModelConfig.audioSampleRate * minSeconds) {
      return null;
    }

    await ensureModelReady();
    final extractor = _extractor;
    if (!_modelReady || extractor == null) return null;

    final stream = extractor.createStream();
    try {
      stream.acceptWaveform(
        samples: samples,
        sampleRate: MlModelConfig.audioSampleRate,
      );
      stream.inputFinished();
      if (!extractor.isReady(stream)) return null;

      final embedding = extractor.compute(stream);
      if (embedding.isEmpty) return null;
      return Float32List.fromList(embedding);
    } finally {
      stream.free();
    }
  }

  ({_SpeakerProfile? profile, double score}) _findBestMatch(
    Float32List embedding,
  ) {
    _SpeakerProfile? best;
    var bestScore = -1.0;
    for (final profile in _profiles) {
      final score = profile.bestSimilarityTo(embedding);
      if (score > bestScore) {
        bestScore = score;
        best = profile;
      }
    }
    return (profile: best, score: bestScore);
  }

  double? _scoreForLabel(Float32List embedding, String label) {
    for (final profile in _profiles) {
      if (profile.label == label) {
        return profile.bestSimilarityTo(embedding);
      }
    }
    return null;
  }

  /// Test-only: register a speaker profile without running the embedding model.
  @visibleForTesting
  void debugRegisterSpeaker(String label, Float32List embedding) {
    _profiles.add(_SpeakerProfile(label, Float32List.fromList(embedding)));
    final match = RegExp(r'Speaker (\d+)$').firstMatch(label);
    if (match != null) {
      final index = int.parse(match.group(1)!);
      if (index >= _nextSpeakerIndex) {
        _nextSpeakerIndex = index + 1;
      }
    }
  }

  /// Test-only: probe matching logic without the ONNX extractor.
  @visibleForTesting
  SpeakerProbeResult debugIdentifyFromEmbedding(
    Float32List embedding, {
    String? relativeToLabel,
  }) {
    if (_profiles.isEmpty) return const SpeakerProbeResult.inconclusive();

    final match = _findBestMatch(embedding);
    final pendingScore = relativeToLabel == null
        ? null
        : _scoreForLabel(embedding, relativeToLabel);

    if (match.profile != null &&
        match.score >= MlModelConfig.diarizationSpeakerMatchThreshold) {
      return SpeakerProbeResult.matched(
        match.profile!.label,
        bestScore: match.score,
        pendingSpeakerScore: pendingScore,
      );
    }
    return SpeakerProbeResult.unknownNewVoice(
      bestScore: match.score >= 0 ? match.score : null,
      bestLabel: match.profile?.label,
      pendingSpeakerScore: pendingScore,
    );
  }

  /// Test-only: how many stored samples a speaker currently has.
  @visibleForTesting
  int debugSampleCount(String label) {
    for (final profile in _profiles) {
      if (profile.label == label) return profile.sampleCount;
    }
    return 0;
  }

  bool get isModelReady => _modelReady;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _profiles.clear();
    _extractor?.free();
    _extractor = null;
    _modelReady = false;
    _loading = null;
  }
}

/// A known speaker's reference embeddings.
///
/// Keeps up to [_maxSamples] individual embeddings (not a single blended
/// average) — a real voice varies noticeably between short utterances, and
/// matching against the single best-fitting past sample is more forgiving
/// of that variation than matching against one diluted mean vector, which
/// can drift far enough from any individual utterance to cause false
/// negatives (a real device log showed exactly this: a same-speaker
/// utterance scored 0.183 against a running-average centroid — likely
/// because the low-similarity moment where the average sat was worse than
/// any single sample would have been).
class _SpeakerProfile {
  _SpeakerProfile(this.label, Float32List embedding) : _samples = [embedding];

  static const _maxSamples = 8;

  final String label;
  final List<Float32List> _samples;

  int get sampleCount => _samples.length;

  /// Best (max) similarity between [embedding] and any stored sample.
  double bestSimilarityTo(Float32List embedding) {
    var best = -1.0;
    for (final sample in _samples) {
      final score = _cosineSimilarity(embedding, sample);
      if (score > best) best = score;
    }
    return best;
  }

  void addSample(Float32List embedding) {
    _samples.add(embedding);
    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
  }
}

double _cosineSimilarity(Float32List a, Float32List b) {
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0.0;
  return dot / (math.sqrt(normA) * math.sqrt(normB));
}
