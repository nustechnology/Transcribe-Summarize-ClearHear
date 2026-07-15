import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';

import '../config/ml_model_config.dart';
import '../model/conversation_segment.dart';
import '../util/asr_text_util.dart';
import '../util/pcm_audio_util.dart';
import 'audio_recorder_service.dart';
import 'conversation_segment_capture.dart';
import 'whisper_kit_service.dart';

/// Records conversation segments and transcribes them with whisper_kit.
///
/// Utterance boundaries come from [VadHandler] (Silero VAD): the same PCM
/// stream already produced for the on-screen waveform is fed into VAD's
/// `onSpeechEnd`, so a segment is captured and transcribed the instant a
/// phrase ends, rather than waiting for the user to pause/stop. While a
/// phrase is in progress (`onSpeechStart` .. `onSpeechEnd`), the buffer
/// captured so far is periodically re-decoded to surface partial text.
class LiveTranscriptService {
  LiveTranscriptService({
    required AudioRecorderService audioRecorderService,
    required WhisperKitService whisperKitService,
    ConversationSegmentCapture? segmentCapture,
    VadHandler? vadHandler,
    this.onPartialText,
    this.onSegmentFinalized,
    this.onBackgroundProcessingChanged,
  })  : _audioRecorderService = audioRecorderService,
        _whisperKitService = whisperKitService,
        _segmentCapture = segmentCapture ?? ConversationSegmentCapture(),
        _vad = vadHandler ?? VadHandler.create();

  final AudioRecorderService _audioRecorderService;
  final WhisperKitService _whisperKitService;
  final ConversationSegmentCapture _segmentCapture;
  final VadHandler _vad;

  // `forceEndSpeech()` (triggered via `pauseListening`) only fires
  // `onSpeechEnd` if enough positive frames were seen; a short in-progress
  // utterance can be dropped silently, in which case `_flushCompleter` would
  // never complete. Bound the wait so pause/finish can't hang forever.
  static const _flushTimeout = Duration(seconds: 3);

  Future<void> _awaitFlush(Completer<void>? completer) async {
    if (completer == null) return;
    await completer.future.timeout(
      _flushTimeout,
      onTimeout: () {
        debugPrint('[LiveTranscript] flush wait timed out, continuing');
      },
    );
  }

  /// Called with the latest re-decoded guess of the in-progress phrase.
  void Function(String partialText)? onPartialText;

  /// Called as soon as a committed segment finishes transcribing.
  void Function(ConversationSegment segment)? onSegmentFinalized;

  /// Called when background transcription starts or stops after a pause.
  void Function(bool isProcessing)? onBackgroundProcessingChanged;

  StreamController<Uint8List>? _pcmStreamController;
  StreamSubscription<void>? _speechStartSubscription;
  StreamSubscription<List<double>>? _speechEndSubscription;
  Future<void>? _pendingCommit;
  Completer<void>? _flushCompleter;

  final BytesBuilder _partialBuffer = BytesBuilder(copy: false);
  Timer? _partialTimer;
  bool _isRefreshingPartial = false;
  bool _speechInProgress = false;

  /// Bumped on every speech start/end so overlapping utterances can be told
  /// apart: commits are queued in order (never overlap in `commitSamples`),
  /// and a commit only clears the on-screen frozen partial if no newer
  /// utterance has started since it was queued.
  int _utteranceGeneration = 0;

  bool _isActive = false;
  bool _isPaused = false;
  bool _isBackgroundProcessing = false;

  /// Incremented on each pause cycle so stale background completions are ignored.
  int _pauseGeneration = 0;

  /// Chains background transcription work across pause cycles.
  Future<void>? _backgroundPendingCommit;

  bool get isPaused => _isPaused;

  bool get isBackgroundProcessing => _isBackgroundProcessing;

  /// Starts VAD exactly once for the whole session (on a long-lived audio
  /// stream). Pause/resume only start/stop feeding that stream — they never
  /// call `startListening`/`pauseListening` again, since the plugin expects
  /// a single attached stream for its lifetime; calling `startListening` a
  /// second time on resume left it not receiving events afterward.
  Future<void> start() async {
    if (_isActive) return;

    await _whisperKitService.ensureModelReady();
    await _segmentCapture.start();
    _isPaused = false;

    _speechStartSubscription ??= _vad.onSpeechStart.listen(_handleSpeechStart);
    _speechEndSubscription ??= _vad.onSpeechEnd.listen(_handleSpeechEnd);

    try {
      final pcmStreamController = StreamController<Uint8List>.broadcast();
      _pcmStreamController = pcmStreamController;
      await _vad.startListening(
        audioStream: pcmStreamController.stream,
        submitUserSpeechOnPause: true,
        baseAssetPath: MlModelConfig.vadModelAssetBasePath,
      );
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
      _isActive = true;
    } catch (_) {
      _isActive = false;
      rethrow;
    }
  }

  /// Pause recording: just stops feeding the mic stream. VAD itself stays
  /// attached/listening (untouched) so [resume] can simply start feeding it
  /// again.
  Future<LiveTranscriptResult> pause() async {
    if (!_isActive || _isPaused) {
      return _buildCurrentResult();
    }

    _isActive = false;
    _isPaused = true;
    _stopPartialTimer();
    onPartialText?.call('');

    // Same flush path as `finish()`: force VAD to end whatever utterance is
    // in progress (`submitUserSpeechOnPause: true`) so it is committed and
    // transcribed instead of being silently dropped from the paused result.
    final flushCompleter = _speechInProgress ? Completer<void>() : null;
    _flushCompleter = flushCompleter;
    try {
      await _vad.pauseListening();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] pause VAD flush failed: $error');
      debugPrint('$stackTrace');
    }

    await _awaitFlush(flushCompleter);
    _flushCompleter = null;

    try {
      await _audioRecorderService.stopStreaming();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] pause stop streaming failed: $error');
      debugPrint('$stackTrace');
    }

    // Don't await pending transcription — let it complete in the background
    // so the user can resume immediately.
    _startBackgroundTranscription();

    debugPrint('[LiveTranscript] paused (returned immediately)');

    return _buildCurrentResult();
  }

  /// Kicks off background transcription of segments captured before [pause]
  /// so the user can resume mic capture without waiting for inference.
  void _startBackgroundTranscription() {
    final generation = ++_pauseGeneration;
    _isBackgroundProcessing = true;
    onBackgroundProcessingChanged?.call(true);

    final pendingCommit = _pendingCommit;
    if (pendingCommit == null) {
      _isBackgroundProcessing = false;
      onBackgroundProcessingChanged?.call(false);
      return;
    }

    // Snapshot the count of segments at pause time so the safety net below
    // only touches pre-pause segments, not any captured after resume.
    final snapshotCount = _segmentCapture.segments.length;

    // Chain from the previous background future so rapid pause/resume cycles
    // stay serialized — each safety-net waits for prior work to finish first.
    _backgroundPendingCommit = (_backgroundPendingCommit ?? Future.value())
        .then((_) => pendingCommit)
        .then((_) async {
      final segments = _segmentCapture.segments;
      final prePauseSegments = segments.length >= snapshotCount
          ? segments.sublist(0, snapshotCount)
          : segments;
      final pending = prePauseSegments
          .where((s) => s.whisperText.trim().isEmpty)
          .toList(growable: false);
      if (pending.isNotEmpty) {
        try {
          await _whisperKitService.buildTranscriptFromSegments(pending);
          for (final s in pending) {
            if (s.whisperText.trim().isNotEmpty) {
              onSegmentFinalized?.call(s);
            }
          }
        } catch (error, stackTrace) {
          debugPrint(
            '[LiveTranscript] background safety net failed: $error',
          );
          debugPrint('$stackTrace');
        }
      }
    }).whenComplete(() {
      if (generation == _pauseGeneration) {
        _isBackgroundProcessing = false;
        onBackgroundProcessingChanged?.call(false);
      }
    });
  }

  /// Resume recording after [pause] by feeding the same, still-attached
  /// VAD audio stream again.
  Future<void> resume() async {
    if (_isActive || !_isPaused) return;

    try {
      // `pauseListening` left the VAD handler internally paused (ignoring
      // audio until told otherwise). Calling `startListening` again with the
      // same, still-open stream hits the handler's early-return "resume from
      // paused" path rather than recreating the subscription, so this only
      // flips it back to listening.
      await _vad.startListening(
        audioStream: _pcmStreamController?.stream,
        submitUserSpeechOnPause: true,
        baseAssetPath: MlModelConfig.vadModelAssetBasePath,
      );
      await _audioRecorderService.startStreaming(
        onChunk: (chunk) => _handleChunk(chunk),
      );
      _isActive = true;
      _isPaused = false;
    } catch (_) {
      _isActive = false;
      rethrow;
    }
  }

  /// Stop streaming, transcribe saved segments with WhisperKit, log only.
  Future<LiveTranscriptResult> finish() async {
    _isActive = false;
    _isPaused = false;
    _stopPartialTimer();
    onPartialText?.call('');

    // Forces VAD to flush any in-progress utterance to `onSpeechEnd`
    // (`submitUserSpeechOnPause: true`) before we tear the stream down, so
    // a trailing unfinished phrase still gets force-finalized on stop.
    // `pauseListening` can return before `_handleSpeechEnd` runs, so wait on
    // a completer that `_handleSpeechEnd` itself completes (after assigning
    // `_pendingCommit`) rather than a fixed delay.
    final flushCompleter = _speechInProgress ? Completer<void>() : null;
    _flushCompleter = flushCompleter;
    try {
      await _vad.pauseListening();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] VAD flush-on-stop failed: $error');
      debugPrint('$stackTrace');
    }

    await _awaitFlush(flushCompleter);
    _flushCompleter = null;
    await _pendingCommit;

    if (_backgroundPendingCommit != null) {
      await _backgroundPendingCommit;
    }

    try {
      await _vad.stopListening();
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] VAD stop failed: $error');
      debugPrint('$stackTrace');
    }

    if (_audioRecorderService.isStreaming) {
      try {
        await _audioRecorderService.stopStreaming();
      } catch (error, stackTrace) {
        debugPrint('[LiveTranscript] stop streaming failed: $error');
        debugPrint('$stackTrace');
      }
    }

    final result = await _transcribePendingSegments();

    debugPrint(
      '[LiveTranscript] finished (${result.segments.length} segments, '
      'whisper=${result.usedWhisper}):\n${result.text}',
    );

    return result;
  }

  void _handleChunk(Uint8List chunk) {
    if (!_isActive) return;

    final pcm = recorderChunkToPcm16(chunk);
    if (pcm.isEmpty) return;

    _pcmStreamController?.add(pcm);
    if (_speechInProgress) {
      _partialBuffer.add(pcm);
    }
  }

  void _handleSpeechStart(void _) {
    _utteranceGeneration++;
    _partialBuffer.clear();
    _speechInProgress = true;
    _startPartialTimer();
  }

  void _handleSpeechEnd(List<double> samples) {
    _speechInProgress = false;
    // Freeze the last partial guess on screen (stop refreshing it) instead
    // of clearing it here — clearing happens the instant the final text is
    // ready, so the UI swaps italic partial -> bold final directly with no
    // empty gap in between.
    _stopPartialTimer();
    final generation = ++_utteranceGeneration;
    // Chain onto the previous commit instead of overwriting it, so
    // `commitSamples` never runs concurrently for two utterances (which
    // could otherwise both grab the same _nextId/WAV path before either
    // increments it).
    final previousCommit = _pendingCommit ?? Future<void>.value();
    _pendingCommit = previousCommit.then(
      (_) => _commitAndTranscribe(samples, generation),
    );
    if (_flushCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _commitAndTranscribe(
      List<double> samples, int generation) async {
    final segment = await _segmentCapture.commitSamples(samples);
    if (segment == null) {
      _clearFrozenPartial(generation);
      return;
    }

    debugPrint(
      '[LiveTranscript] saved segment ${segment.id}: ${segment.wavPath}',
    );

    try {
      final text = await _whisperKitService.transcribeWav(segment.wavPath);
      segment.whisperText = text;
      onSegmentFinalized?.call(segment);
    } catch (error, stackTrace) {
      debugPrint(
        '[LiveTranscript] segment ${segment.id} transcribe failed: $error',
      );
      debugPrint('$stackTrace');
    } finally {
      _clearFrozenPartial(generation);
    }
  }

  /// Only clears the on-screen frozen partial if no newer utterance has
  /// started since this commit was queued — otherwise an older commit could
  /// wipe out the partial text of an utterance still in progress.
  void _clearFrozenPartial(int generation) {
    if (generation != _utteranceGeneration) return;
    _partialBuffer.clear();
    onPartialText?.call('');
  }

  void _startPartialTimer() {
    _partialTimer?.cancel();
    _partialTimer = Timer.periodic(
      const Duration(milliseconds: MlModelConfig.partialRefreshIntervalMs),
      (_) => unawaited(_refreshPartialText()),
    );
  }

  void _stopPartialTimer() {
    _partialTimer?.cancel();
    _partialTimer = null;
  }

  Future<void> _refreshPartialText() async {
    if (_isRefreshingPartial || !_isActive || !_speechInProgress) return;

    final pcm = _partialBuffer.toBytes();
    if (pcm.length < MlModelConfig.minPartialPcmBytes) return;

    _isRefreshingPartial = true;
    try {
      final wavPath = await _segmentCapture.writePartialWav(pcm);
      final text = await _whisperKitService.transcribeWav(wavPath);
      if (_isActive && _speechInProgress) {
        onPartialText?.call(text);
      }
    } catch (error, stackTrace) {
      debugPrint('[LiveTranscript] partial refresh failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _isRefreshingPartial = false;
    }
  }

  Future<LiveTranscriptResult> _buildCurrentResult() {
    return Future.value(
      LiveTranscriptResult(
        text: _combinedDisplayText(),
        segments: List.unmodifiable(_segmentCapture.segments),
        usedWhisper: _segmentCapture.segments
            .any((segment) => segment.whisperText.trim().isNotEmpty),
      ),
    );
  }

  String _combinedDisplayText() {
    return joinSegmentTexts(
      _segmentCapture.segments.map((segment) => segment.displayText),
    );
  }

  /// Safety net for any segment that finished saving but never finished
  /// transcribing live (e.g. `_commitAndTranscribe` was still in flight).
  Future<LiveTranscriptResult> _transcribePendingSegments() async {
    final segments = List<ConversationSegment>.from(_segmentCapture.segments);
    final pendingSegments = segments
        .where((segment) => segment.whisperText.trim().isEmpty)
        .toList(growable: false);

    var usedWhisper =
        segments.any((segment) => segment.whisperText.trim().isNotEmpty);

    if (pendingSegments.isNotEmpty) {
      try {
        final whisperText = await _whisperKitService
            .buildTranscriptFromSegments(pendingSegments);
        if (whisperText.trim().isNotEmpty) {
          usedWhisper = true;
        }
      } catch (error, stackTrace) {
        debugPrint('[LiveTranscript] WhisperKit segment pass failed: $error');
        debugPrint('$stackTrace');
      }
    }

    return LiveTranscriptResult(
      text: _combinedDisplayText(),
      segments: List.unmodifiable(segments),
      usedWhisper: usedWhisper,
    );
  }

  Future<void> dispose() async {
    _isActive = false;
    _isPaused = false;
    _stopPartialTimer();
    _partialBuffer.clear();
    await _speechStartSubscription?.cancel();
    _speechStartSubscription = null;
    await _speechEndSubscription?.cancel();
    _speechEndSubscription = null;
    await _pcmStreamController?.close();
    _pcmStreamController = null;
    await _vad.dispose();
    await _segmentCapture.dispose();
  }
}
