import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/asr_text_util.dart';
import '../util/asr_timestamp_split.dart';
import '../util/pcm_audio_util.dart';
import '../util/segment_audio_buffer.dart';
import 'audio_recorder_service.dart';
import 'conversation_segment_capture.dart';
import 'sherpa_onnx_service.dart';
import 'speaker_diarization_service.dart';

/// Records audio and transcribes in real time via [SherpaOnnxService].
///
/// Each audio chunk is fed into sherpa-onnx's streaming recognizer.
/// Partial text is emitted immediately after every decode cycle
/// (truly real-time). Utterance boundaries are detected via
/// sherpa-onnx's built-in endpoint detection, and additionally via
/// mid-utterance speaker-change probes (rolling embedding windows) so
/// turns without enough silence still produce separate segments.
///
/// Quality aids for many rapid speakers:
/// - energy gate skips silence/noise probe windows
/// - force-cut splits ASR text by token timestamps when available
/// - pause/finish re-labels segments from retained utterance audio
class LiveTranscriptService {
  LiveTranscriptService({
    required AudioRecorderService audioRecorderService,
    required SherpaOnnxService sherpaOnnxService,
    SpeakerDiarizationService? speakerDiarizationService,
    ConversationSegmentCapture? segmentCapture,
    this.onPartialText,
    this.onPartialSpeakerLabel,
    this.onSegmentFinalized,
  })  : _audioRecorderService = audioRecorderService,
        _sherpaOnnxService = sherpaOnnxService,
        _speakerDiarizationService = speakerDiarizationService,
        _segmentCapture = segmentCapture ?? ConversationSegmentCapture();

  final AudioRecorderService _audioRecorderService;
  final SherpaOnnxService _sherpaOnnxService;
  final SpeakerDiarizationService? _speakerDiarizationService;
  final ConversationSegmentCapture _segmentCapture;

  void Function(String partialText)? onPartialText;

  /// Fired with `null` when a new utterance starts (label still unknown)
  /// and again with the determined label once enough audio has been heard.
  void Function(String? speakerLabel)? onPartialSpeakerLabel;
  void Function(ConversationSegment segment)? onSegmentFinalized;

  OnlineStream? _stream;

  bool _isActive = false;
  bool _isPaused = false;

  /// Total number of audio samples processed since [start], used to derive
  /// session-relative `startMs`/`endMs` for each segment.
  int _processedSampleCount = 0;
  int _segmentStartSampleCount = 0;

  /// Raw audio for the segment currently being built, fed to the speaker
  /// embedding extractor once enough of it has accumulated.
  final List<Float32List> _segmentAudioChunks = [];
  int _segmentBufferedSampleCount = 0;

  /// Speaker label determined early for the current utterance (before it
  /// finalizes), if any. Reused at finalize time instead of recomputing.
  String? _pendingSegmentLabel;
  bool _labelRequestInFlight = false;
  Future<String?>? _earlyLabelFuture;
  bool _probeRequestInFlight = false;

  /// Samples processed when the last speaker-change probe started; used to
  /// throttle probes to [MlModelConfig.diarizationChangeProbeIntervalSeconds].
  int _lastProbeAtSampleCount = 0;

  /// After a force-cut, skip probes until this many samples have been
  /// processed (one probe interval of cooldown).
  int _probeCooldownUntilSampleCount = 0;

  /// Consecutive probes that disagreed with the pending speaker; reset when
  /// a probe agrees again. Used with
  /// [requiredSpeakerChangeConfirmations] for fast-but-stable cuts.
  int _speakerChangeStreak = 0;

  /// Buffer (seconds) added to the audio-level cut point when splitting ASR
  /// timestamps. Streaming ASR decoding lags audio (left-context = 64 frames
  /// ≈ 640 ms), so tokens near the boundary may have timestamps later than
  /// their audio position. This buffer keeps the last few words with the
  /// outgoing speaker instead of discarding them.
  static const _kAsrTimestampBufferSeconds = 0.4;

  /// Text attributed to the next speaker after a timestamp split at
  /// force-cut (ASR stream was reset, so this is carried until the next
  /// segment commits).
  String? _carryOverText;

  /// Incremented every time a new utterance starts; guards against an
  /// in-flight early-label request resolving after its utterance has
  /// already finalized and being misapplied to the next one.
  int _segmentGeneration = 0;

  bool get isPaused => _isPaused;

  Future<void> start() async {
    if (_isActive) return;

    // Usually instant after app preload; used to re-load the full ASR
    // recognizer on every Start (1–2s stall) before `_modelReady` was checked.
    await _sherpaOnnxService.ensureModelReady();
    // Warm diarization in the background; don't block mic/waveform on it.
    unawaited(_speakerDiarizationService?.ensureModelReady().catchError(
      (error, stackTrace) {
        debugPrint('[LiveTranscript] diarization model warm-up failed: $error');
      },
    ));
    _speakerDiarizationService?.resetSession();
    _segmentCapture.start();
    _isPaused = false;
    _processedSampleCount = 0;
    _segmentStartSampleCount = 0;
    _segmentAudioChunks.clear();
    _segmentBufferedSampleCount = 0;
    _pendingSegmentLabel = null;
    _labelRequestInFlight = false;
    _earlyLabelFuture = null;
    _probeRequestInFlight = false;
    _lastProbeAtSampleCount = 0;
    _probeCooldownUntilSampleCount = 0;
    _speakerChangeStreak = 0;
    _carryOverText = null;
    _segmentGeneration++;

    _stream = _sherpaOnnxService.createStream();

    _isActive = true;
    try {
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
    } catch (error) {
      _isActive = false;
      _stream = null;
      rethrow;
    }
  }

  Future<LiveTranscriptResult> pause() async {
    if (!_isActive || _isPaused) return _buildCurrentResult();

    _isActive = false;
    onPartialText?.call('');

    try {
      await _audioRecorderService.stopStreaming();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] pause stop streaming failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }

    _isPaused = true;
    await _flushRemainingAudio();
    // Skip full-session relabel on pause — Cam++ over every segment would
    // freeze the UI. Live labels stay; finish() refines once at the end.

    final result = _buildCurrentResult();
    debugPrint(
      '[LiveTranscript] paused '
      '(${result.segments.length} segments, asr=${result.usedAsr})',
    );
    if (kDebugMode) {
      debugPrint('[LiveTranscript] paused text:\n${result.text}');
    }
    return result;
  }

  Future<void> resume() async {
    if (_isActive || !_isPaused) return;

    _stream = _sherpaOnnxService.createStream();
    _isActive = true;
    try {
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
      _isPaused = false;
    } catch (error) {
      _isActive = false;
      rethrow;
    }
  }

  Future<LiveTranscriptResult> finish() async {
    // Let the stop-button loading indicator paint before any heavy work.
    await Future<void>.delayed(Duration.zero);

    _isActive = false;
    _isPaused = false;
    onPartialText?.call('');

    if (_audioRecorderService.isStreaming) {
      await _audioRecorderService.stopStreaming();
    }

    await _flushRemainingAudio();
    // Return immediately with live labels. Caller should invoke
    // [refineSpeakerLabels] after unlocking the UI so Cam++ does not freeze
    // the stop spinner.

    final result = _buildCurrentResult();
    debugPrint(
      '[LiveTranscript] finished '
      '(${result.segments.length} segments, asr=${result.usedAsr})',
    );
    if (kDebugMode) {
      debugPrint('[LiveTranscript] finished text:\n${result.text}');
    }
    return result;
  }

  /// Re-runs speaker matching on retained segment audio. Yields between
  /// segments so the UI can keep animating. Safe to call after [finish]
  /// and before [dispose].
  Future<LiveTranscriptResult> refineSpeakerLabels({
    bool clearAudioAfter = true,
  }) async {
    await _relabelCommittedSegments(clearAudioAfter: clearAudioAfter);
    return _buildCurrentResult();
  }

  void _handleChunk(Uint8List chunk) {
    if (!_isActive) return;

    final pcm = recorderChunkToPcm16(chunk);
    if (pcm.isEmpty) return;

    final stream = _stream;
    if (stream == null) return;

    final samples = pcm16ToFloat32(pcm);
    _sherpaOnnxService.acceptWaveform(stream, samples);
    _processedSampleCount += samples.length;
    _segmentAudioChunks.add(samples);
    _segmentBufferedSampleCount += samples.length;

    final text = _sherpaOnnxService.decodeAndGetText(stream);
    final display = _mergeCarryOver(text);
    if (display.isNotEmpty) {
      onPartialText?.call(display);
    }

    _maybeRequestEarlyLabel();
    _maybeProbeSpeakerChange();

    if (_sherpaOnnxService.isEndpoint(stream)) {
      final finalText = _sherpaOnnxService.finalizeStream(stream);
      final merged = _takeCarryOverMerged(finalText);
      if (merged.isNotEmpty) {
        final pendingLabel = _pendingSegmentLabel;
        final earlyFuture = _earlyLabelFuture;
        unawaited(
          _finalizeSegment(
            merged,
            precomputedLabel: pendingLabel,
            earlyLabelFuture: earlyFuture,
          ),
        );
        onPartialText?.call('');
      } else {
        _segmentAudioChunks.clear();
      }
      _beginNextUtterance(seedChunks: const []);
    }
  }

  /// Kicks off speaker labeling as soon as enough audio has accumulated for
  /// the utterance currently being spoken — well before it finalizes — so
  /// the label appears live rather than only once the full utterance ends.
  void _maybeRequestEarlyLabel() {
    final diarizationService = _speakerDiarizationService;
    if (diarizationService == null) return;
    if (_pendingSegmentLabel != null || _labelRequestInFlight) return;

    final minSamples = (MlModelConfig.audioSampleRate *
            MlModelConfig.diarizationMinSegmentSeconds)
        .round();
    if (_segmentBufferedSampleCount < minSamples) return;

    final samples = concatFloat32Chunks(_segmentAudioChunks);
    if (!hasSpeechEnergy(
      samples,
      minRms: MlModelConfig.diarizationSpeechMinRms,
    )) {
      return;
    }

    _labelRequestInFlight = true;
    final generation = _segmentGeneration;
    final future = diarizationService.labelSegment(samples);
    _earlyLabelFuture = future;

    unawaited(
      future.then((label) {
        if (generation != _segmentGeneration) return; // stale for live badge
        _pendingSegmentLabel = label;
        _labelRequestInFlight = false;
        onPartialSpeakerLabel?.call(label);
      }).catchError((error, stackTrace) {
        debugPrint('[LiveTranscript] early speaker labeling failed: $error');
        debugPrint('$stackTrace');
        if (generation == _segmentGeneration) {
          _labelRequestInFlight = false;
          _earlyLabelFuture = null;
        }
      }),
    );
  }

  /// Periodically embeds the trailing audio window and force-cuts the
  /// utterance when the voice no longer matches [_pendingSegmentLabel].
  void _maybeProbeSpeakerChange() {
    final diarizationService = _speakerDiarizationService;
    if (diarizationService == null) return;
    if (_pendingSegmentLabel == null) return;
    if (_labelRequestInFlight || _probeRequestInFlight) return;
    if (_processedSampleCount < _probeCooldownUntilSampleCount) return;

    final intervalSamples = (MlModelConfig.audioSampleRate *
            MlModelConfig.diarizationChangeProbeIntervalSeconds)
        .round();
    if (_processedSampleCount - _lastProbeAtSampleCount < intervalSamples) {
      return;
    }

    final windowSamples = (MlModelConfig.audioSampleRate *
            MlModelConfig.diarizationChangeWindowSeconds)
        .round();
    if (_segmentBufferedSampleCount < windowSamples) return;

    // Need audio before the window so the previous speaker keeps a segment.
    if (_segmentBufferedSampleCount <= windowSamples) return;

    final window = takeLastSamples(_segmentAudioChunks, windowSamples);
    if (!hasSpeechEnergy(
      window,
      minRms: MlModelConfig.diarizationSpeechMinRms,
    )) {
      _lastProbeAtSampleCount = _processedSampleCount;
      _speakerChangeStreak = 0;
      return;
    }

    _lastProbeAtSampleCount = _processedSampleCount;
    _probeRequestInFlight = true;
    final generation = _segmentGeneration;
    final pendingLabel = _pendingSegmentLabel!;

    unawaited(
      diarizationService
          .identifySpeaker(window, relativeToLabel: pendingLabel)
          .then((probe) {
        if (generation != _segmentGeneration) {
          // Utterance already moved on (endpoint / prior cut); in-flight
          // flag was cleared by [_beginNextUtterance].
          return;
        }
        _probeRequestInFlight = false;

        final shouldCut = shouldForceCutOnSpeakerChange(
          pendingLabel: pendingLabel,
          probeMatchedLabel: probe.matchedLabel,
          probeIsUnknownNewVoice: probe.isUnknownNewVoice,
          pendingSpeakerScore: probe.pendingSpeakerScore,
          bestScore: probe.bestScore,
        );

        if (!shouldCut) {
          _speakerChangeStreak = 0;
          return;
        }

        _speakerChangeStreak++;
        final needed = requiredSpeakerChangeConfirmations(
          probeMatchedLabel: probe.matchedLabel,
          pendingSpeakerScore: probe.pendingSpeakerScore,
          bestScore: probe.bestScore,
        );
        debugPrint(
          '[LiveTranscript] speaker change probe '
          '(pending=$pendingLabel probe=${probe.matchedLabel ?? "new"} '
          'score=${probe.bestScore?.toStringAsFixed(3)} '
          'pendingScore=${probe.pendingSpeakerScore?.toStringAsFixed(3)} '
          'streak=$_speakerChangeStreak/$needed)',
        );
        if (_speakerChangeStreak < needed) return;

        _speakerChangeStreak = 0;
        _forceCutOnSpeakerChange(windowSamples: windowSamples);
      }).catchError((error, stackTrace) {
        debugPrint('[LiveTranscript] speaker-change probe failed: $error');
        debugPrint('$stackTrace');
        if (generation == _segmentGeneration) {
          _probeRequestInFlight = false;
        }
      }),
    );
  }

  void _forceCutOnSpeakerChange({required int windowSamples}) {
    final stream = _stream;
    if (stream == null) return;

    final split = splitTrailingWindow(_segmentAudioChunks, windowSamples);
    final pendingLabel = _pendingSegmentLabel;

    // Attribute samples up to the start of the new-speaker window to the
    // outgoing segment's end time.
    final cutEndSampleCount = _processedSampleCount - split.tail.length;
    final cutSeconds =
        (cutEndSampleCount - _segmentStartSampleCount) /
            MlModelConfig.audioSampleRate;
    final utteranceSeconds =
        (_processedSampleCount - _segmentStartSampleCount) /
            MlModelConfig.audioSampleRate;

    final asr = _sherpaOnnxService.finalizeStreamResult(stream);
    final textSplit = splitAsrTextAtCutSeconds(
      fullText: asr.text,
      tokens: asr.tokens,
      timestamps: asr.timestamps,
      cutSeconds: cutSeconds + _kAsrTimestampBufferSeconds,
      utteranceDurationSeconds: utteranceSeconds,
    );
    // Carry-over from a prior cut still belongs to this (outgoing) speaker.
    final prefixText = _takeCarryOverMerged(textSplit.prefix);

    _segmentAudioChunks
      ..clear()
      ..addAll(split.prefix.isEmpty ? const <Float32List>[] : [split.prefix]);

    if (prefixText.isNotEmpty) {
      _commitSegmentSync(
        prefixText,
        precomputedLabel: pendingLabel,
        endSampleCount: cutEndSampleCount,
      );
    } else {
      _segmentAudioChunks.clear();
    }

    _carryOverText = null;
    onPartialText?.call('');

    final cooldownSamples = (MlModelConfig.audioSampleRate *
            MlModelConfig.diarizationChangeProbeIntervalSeconds)
        .round();
    _probeCooldownUntilSampleCount =
        _processedSampleCount + cooldownSamples;

    _stream = _sherpaOnnxService.createStream();
    if (split.tail.isNotEmpty) {
      _sherpaOnnxService.acceptWaveform(_stream!, split.tail);
    }
    _beginNextUtterance(
      seedChunks: split.tail.isEmpty ? const <Float32List>[] : [split.tail],
      segmentStartSampleCount: cutEndSampleCount,
    );
  }

  void _beginNextUtterance({
    required List<Float32List> seedChunks,
    int? segmentStartSampleCount,
  }) {
    _segmentAudioChunks
      ..clear()
      ..addAll(seedChunks);
    _segmentBufferedSampleCount = 0;
    for (final chunk in seedChunks) {
      _segmentBufferedSampleCount += chunk.length;
    }
    _segmentStartSampleCount =
        segmentStartSampleCount ?? _processedSampleCount;
    _pendingSegmentLabel = null;
    _labelRequestInFlight = false;
    _earlyLabelFuture = null;
    _probeRequestInFlight = false;
    _speakerChangeStreak = 0;
    _segmentGeneration++;
    onPartialSpeakerLabel?.call(null);

    _maybeRequestEarlyLabel();
  }

  Future<void> _flushRemainingAudio() async {
    final stream = _stream;
    if (stream == null) {
      final carry = _takeCarryOverMerged('');
      if (carry.isNotEmpty) {
        await _finalizeSegment(
          carry,
          precomputedLabel: _pendingSegmentLabel,
          earlyLabelFuture: _earlyLabelFuture,
        );
      }
      return;
    }

    _stream = null;

    stream.inputFinished();

    final text = _sherpaOnnxService.decodeAndGetText(stream);
    final merged = _takeCarryOverMerged(text);
    final pendingLabel = _pendingSegmentLabel;
    final earlyFuture = _earlyLabelFuture;
    if (merged.isNotEmpty) {
      await _finalizeSegment(
        merged,
        precomputedLabel: pendingLabel,
        earlyLabelFuture: earlyFuture,
      );
    } else {
      _segmentAudioChunks.clear();
    }
    _segmentBufferedSampleCount = 0;
    _pendingSegmentLabel = null;
    _labelRequestInFlight = false;
    _earlyLabelFuture = null;
    _probeRequestInFlight = false;
    _speakerChangeStreak = 0;
    _segmentGeneration++;
    onPartialSpeakerLabel?.call(null);
  }

  Future<void> _relabelCommittedSegments({required bool clearAudioAfter}) async {
    final diarizationService = _speakerDiarizationService;
    if (diarizationService == null) return;

    try {
      await diarizationService.relabelSegments(_segmentCapture.segments);
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] session relabel failed: $error');
      debugPrint('$stackTrace');
    }

    if (clearAudioAfter) {
      for (final segment in _segmentCapture.segments) {
        segment.clearAudioSamples();
      }
    }
  }

  /// Commits a finalized segment, attaches a speaker label (best-effort),
  /// then notifies [onSegmentFinalized] — labels are ready by the time the
  /// UI is told about the segment. Reuses [precomputedLabel] / the in-flight
  /// early-label future instead of starting a second [labelSegment] that
  /// would race and mint "Speaker 2" while "Speaker 1" was never shown.
  Future<void> _finalizeSegment(
    String text, {
    String? precomputedLabel,
    Future<String?>? earlyLabelFuture,
  }) async {
    if (precomputedLabel != null) {
      _commitSegmentSync(text, precomputedLabel: precomputedLabel);
      return;
    }

    final samples = concatFloat32Chunks(_segmentAudioChunks);
    final segment = _commitSegmentSync(text, audioSamples: samples);

    try {
      if (earlyLabelFuture != null) {
        // Prefer the in-flight early label so we never mint a second
        // "Speaker N" from a concurrent finalize pass on different audio.
        segment.speakerLabel = await earlyLabelFuture;
      }
      if (segment.speakerLabel == null) {
        final diarizationService = _speakerDiarizationService;
        if (diarizationService != null) {
          segment.speakerLabel = await diarizationService.labelSegment(samples);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] speaker labeling failed: $error');
      debugPrint('$stackTrace');
    }

    onSegmentFinalized?.call(segment);
  }

  ConversationSegment _commitSegmentSync(
    String text, {
    String? precomputedLabel,
    int? endSampleCount,
    Float32List? audioSamples,
  }) {
    final startMs =
        _segmentStartSampleCount * 1000 ~/ MlModelConfig.audioSampleRate;
    final endMs = (endSampleCount ?? _processedSampleCount) *
        1000 ~/
        MlModelConfig.audioSampleRate;
    final audio = audioSamples ?? concatFloat32Chunks(_segmentAudioChunks);
    _segmentAudioChunks.clear();

    final segment = _segmentCapture.commitSegment(
      text: text,
      startMs: startMs,
      endMs: endMs,
    );
    if (audio.isNotEmpty) {
      segment.audioSamples = Float32List.fromList(audio);
    }

    if (precomputedLabel != null) {
      segment.speakerLabel = precomputedLabel;
      onSegmentFinalized?.call(segment);
    }
    return segment;
  }

  String _mergeCarryOver(String text) {
    final carry = _carryOverText;
    if (carry == null || carry.isEmpty) return text;
    if (text.isEmpty) return carry;
    return '$carry $text';
  }

  String _takeCarryOverMerged(String text) {
    final merged = _mergeCarryOver(text);
    _carryOverText = null;
    return merged;
  }

  LiveTranscriptResult _buildCurrentResult() {
    return LiveTranscriptResult(
      text: _combinedDisplayText(),
      segments: List.unmodifiable(_segmentCapture.segments),
      usedAsr: _segmentCapture.segments.any((s) => s.hasText),
    );
  }

  String _combinedDisplayText() {
    return joinSegmentTexts(
      _segmentCapture.segments.map((s) => s.displayText),
    );
  }

  Future<void> dispose() async {
    _isActive = false;
    _isPaused = false;
    _stream = null;
    _segmentAudioChunks.clear();
    _carryOverText = null;
    for (final segment in _segmentCapture.segments) {
      segment.clearAudioSamples();
    }
    try {
      if (_audioRecorderService.isStreaming) {
        await _audioRecorderService.stopStreaming();
      }
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] dispose stop streaming failed: $error');
      debugPrint('$stackTrace');
    }
    _segmentCapture.dispose();
  }
}

Float32List pcm16ToFloat32(Uint8List pcm) {
  final sampleCount = pcm.length ~/ 2;
  final result = Float32List(sampleCount);
  final view = ByteData.sublistView(pcm);
  for (var i = 0; i < sampleCount; i++) {
    result[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return result;
}
