import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';
import 'microphone_interruption_adapter.dart';

enum InterruptionState {
  idle,
  active,
  interrupted,
  pausedByInterruption,
  autoSaved
}

class MicrophoneInterruptionManager {
  MicrophoneInterruptionManager({
    required MicrophoneInterruptionAdapter adapter,
    Duration timeoutDuration = const Duration(minutes: 5),
  })  : _adapter = adapter,
        _timeoutDuration = timeoutDuration;

  final MicrophoneInterruptionAdapter _adapter;
  final Duration _timeoutDuration;

  InterruptionState _state = InterruptionState.idle;

  InterruptionState get state => _state;

  final _stateController = StreamController<InterruptionState>.broadcast();

  Stream<InterruptionState> get stateChanges => _stateController.stream;

  StreamSubscription<InterruptionEvent>? _eventSubscription;
  DateTime? _interruptionStartedAt;

  bool _isSessionFinishInProgress = false;
  bool _isSessionActive = false;
  bool _isDisposed = false;
  Timer? _timeoutTimer;

  Future<void> Function()? onPauseCallback;
  Future<void> Function()? onAutoSaveCallback;

  Future<void>? _pendingTransition;

  Future<void> onSessionStarted() async {
    await _pendingTransition;
    final future = _doStartSession();
    _pendingTransition = future;
    try {
      await future;
    } catch (_) {
      _pendingTransition = null;
    }
  }

  Future<void> onSessionEnded() async {
    await _pendingTransition;
    final future = _doEndSession();
    _pendingTransition = future;
    await future;
  }

  Future<void> _doEndSession() async {
    _isSessionActive = false;
    _isSessionFinishInProgress = true;

    try {
      _cancelTimeoutTimer();

      await _eventSubscription?.cancel();
      _eventSubscription = null;

      await _adapter.stopListening();

      _transitionTo(InterruptionState.idle);
    } finally {
      _isSessionFinishInProgress = false;
    }
  }

  Future<void> _doStartSession() async {
    _isSessionActive = true;
    _isSessionFinishInProgress = false;
    _transitionTo(InterruptionState.active);
    try {
      await _adapter.startListening();
      _eventSubscription?.cancel();
      _eventSubscription =
          _adapter.interruptionEvents.listen(_onInterruptionEvent);
    } catch (error, stackTrace) {
      _isSessionActive = false;
      _eventSubscription?.cancel();
      _eventSubscription = null;
      _transitionTo(InterruptionState.idle);
      AppLogger.error(
        message: 'Failed to start listening for microphone interruptions',
        error: error,
        stackTrace: stackTrace,
        tag: 'MicInterruptionManager',
      );
      rethrow;
    }
  }

  void setFinishInProgress(bool value) {
    _isSessionFinishInProgress = value;
  }

  Future<void> onResumed() async {
    if (_state != InterruptionState.pausedByInterruption) return;
    _transitionTo(InterruptionState.active);
    AppLogger.info(
      'Session resumed after interruption',
      tag: 'MicInterruptionManager',
    );
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _cancelTimeoutTimer();
    _eventSubscription?.cancel();
    _eventSubscription = null;
    await _adapter.stopListening();
    await _stateController.close();
  }

  void _transitionTo(InterruptionState newState) {
    if (_isDisposed) return;
    if (_state == newState) return;
    final previous = _state;
    _state = newState;
    _stateController.add(newState);
    if (kDebugMode) {
      debugPrint('[MicInterruptionManager] $previous → $newState');
    }
  }

  void _onInterruptionEvent(InterruptionEvent event) {
    if (_isSessionFinishInProgress) {
      AppLogger.info(
        'Interruption event ignored: session finish in progress',
        tag: 'MicInterruptionManager',
      );
      return;
    }
    if (!_isSessionActive) {
      AppLogger.info(
        'Interruption event ignored: no active session',
        tag: 'MicInterruptionManager',
      );
      return;
    }
    if (_state == InterruptionState.pausedByInterruption &&
        event.type == InterruptionEventType.began) {
      AppLogger.info(
        'Interruption event ignored: already in paused-by-interruption state',
        tag: 'MicInterruptionManager',
      );
      return;
    }

    switch (event.type) {
      case InterruptionEventType.began:
        _handleInterruptionBegan();
      case InterruptionEventType.ended:
        unawaited(_handleInterruptionEnded(event));
    }
  }

  void _handleInterruptionBegan() {
    if (_state != InterruptionState.active) return;
    _interruptionStartedAt = DateTime.now();
    _transitionTo(InterruptionState.interrupted);
    unawaited(() async {
      try {
        await onPauseCallback?.call();
      } catch (error, stackTrace) {
        AppLogger.error(
          message: 'Pause callback failed',
          error: error,
          stackTrace: stackTrace,
          tag: 'MicInterruptionManager',
        );
      }
    }());
    _startTimeoutTimer();
    AppLogger.info(
      'Microphone interrupted at ${_interruptionStartedAt!.toIso8601String()}',
      tag: 'MicInterruptionManager',
    );
  }

  Future<void> _handleInterruptionEnded(InterruptionEvent event) async {
    if (_state != InterruptionState.interrupted) return;

    final elapsed = DateTime.now().difference(_interruptionStartedAt!);
    if (elapsed >= _timeoutDuration) {
      AppLogger.warning(
        'Interruption duration (${elapsed.inSeconds}s) exceeded timeout (${_timeoutDuration.inSeconds}s) — auto-saving session',
        tag: 'MicInterruptionManager',
      );
      await _triggerAutoSave();
      return;
    } else {
      _cancelTimeoutTimer();
    }

    _transitionTo(InterruptionState.pausedByInterruption);

    if (event.shouldResume == true) {
      AppLogger.info(
        'iOS shouldResume — waiting for manual resume',
        tag: 'MicInterruptionManager',
      );
    } else {
      _adapter.verifyMicAvailable().then((available) {
        if (available) {
          AppLogger.info(
            'Microphone available — waiting for manual resume',
            tag: 'MicInterruptionManager',
          );
        } else {
          AppLogger.warning(
            'Mic not available on recovery — user will see error on resume',
            tag: 'MicInterruptionManager',
          );
        }
      }).catchError((error, stackTrace) {
        AppLogger.error(
          message: 'Failed to verify mic availability on recovery',
          error: error,
          stackTrace: stackTrace,
          tag: 'MicInterruptionManager',
        );
      });
    }
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _startTimeoutTimer() {
    _cancelTimeoutTimer();
    _timeoutTimer = Timer(_timeoutDuration, () {
      if (_state == InterruptionState.interrupted) {
        AppLogger.warning(
          'Interruption timeout (${_timeoutDuration.inSeconds}s) elapsed — auto-saving session',
          tag: 'MicInterruptionManager',
        );
        unawaited(_triggerAutoSave());
      }
    });
  }

  Future<void> _triggerAutoSave() async {
    try {
      if (_state == InterruptionState.autoSaved) return;
      _transitionTo(InterruptionState.autoSaved);
      await onAutoSaveCallback?.call();
      AppLogger.info(
        'Session auto-saved successfully',
        tag: 'MicInterruptionManager',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        message: 'Auto-save callback failed',
        error: error,
        stackTrace: stackTrace,
        tag: 'MicInterruptionManager',
      );
    }
  }
}
