import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/service/interruption/microphone_interruption_adapter.dart';
import 'package:transcribe_summarize_clearhear/service/interruption/microphone_interruption_manager.dart';

class _FakeAdapter implements MicrophoneInterruptionAdapter {
  final StreamController<InterruptionEvent> _eventsController =
      StreamController<InterruptionEvent>.broadcast();

  StreamController<InterruptionEvent> get eventsController =>
      _eventsController;

  Object? startError;
  bool startWasCalled = false;
  bool stopWasCalled = false;
  bool verifyAvailableResult = true;
  Object? verifyError;

  @override
  Future<void> startListening() async {
    startWasCalled = true;
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stopListening() async {
    stopWasCalled = true;
  }

  @override
  Future<bool> verifyMicAvailable() async {
    if (verifyError != null) throw verifyError!;
    return verifyAvailableResult;
  }

  @override
  Stream<InterruptionEvent> get interruptionEvents => _eventsController.stream;

  void emitBegan() =>
      _eventsController.add(const InterruptionEvent(InterruptionEventType.began));

  void emitEnded({bool? shouldResume}) =>
      _eventsController.add(InterruptionEvent(InterruptionEventType.ended,
          shouldResume: shouldResume));
}

void main() {
  late _FakeAdapter adapter;
  late MicrophoneInterruptionManager manager;

  const shortTimeout = Duration(milliseconds: 50);

  setUp(() {
    debugPrint = (String? message, {int? wrapWidth}) {};
    adapter = _FakeAdapter();
    manager = MicrophoneInterruptionManager(
      adapter: adapter,
      timeoutDuration: shortTimeout,
    );
  });

  tearDown(() async {
    await manager.dispose();
  });

  group('session lifecycle', () {
    test('onSessionStarted starts listening and transitions to active',
        () async {
      await manager.onSessionStarted();

      expect(adapter.startWasCalled, isTrue);
      expect(manager.state, InterruptionState.active);
    });

    test('onSessionEnded stops listening and transitions to idle', () async {
      await manager.onSessionStarted();
      await manager.onSessionEnded();

      expect(adapter.stopWasCalled, isTrue);
      expect(manager.state, InterruptionState.idle);
    });

    test('onSessionEnded works without a prior start', () async {
      await manager.onSessionEnded();

      expect(adapter.stopWasCalled, isTrue);
      expect(manager.state, InterruptionState.idle);
    });
  });

  group('startListening() failure', () {
    test('rolls back state to idle and clears _pendingTransition', () async {
      adapter.startError = StateError('native channel failed');

      await manager.onSessionStarted();

      expect(manager.state, InterruptionState.idle);
      expect(adapter.startWasCalled, isTrue);
    });

    test('onSessionEnded still works after startListening failure', () async {
      adapter.startError = StateError('native channel failed');

      await manager.onSessionStarted();
      expect(manager.state, InterruptionState.idle);

      await manager.onSessionEnded();

      expect(adapter.stopWasCalled, isTrue);
      expect(manager.state, InterruptionState.idle);
    });

    test('retry onSessionStarted works after previous failure', () async {
      adapter.startError = StateError('native channel failed');
      await manager.onSessionStarted();
      expect(manager.state, InterruptionState.idle);

      adapter.startError = null;
      await manager.onSessionStarted();

      expect(manager.state, InterruptionState.active);
    });
  });

  group('interruption began', () {
    test('calls pause callback and transitions to interrupted', () async {
      await manager.onSessionStarted();
      var pauseCalled = false;
      manager.onPauseCallback = () async {
        pauseCalled = true;
      };

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.interrupted);
      expect(pauseCalled, isTrue);
    });

    test('pause callback failure is caught without crashing', () async {
      await manager.onSessionStarted();
      manager.onPauseCallback = () async {
        throw StateError('pause failed');
      };

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.interrupted);
    });

    test('timer-based timeout triggers auto-save', () async {
      await manager.onSessionStarted();
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      await Future<void>.delayed(shortTimeout * 2);

      expect(manager.state, InterruptionState.autoSaved);
      expect(autoSaveCalled, isTrue);
    });

    test('auto-save callback failure does not crash', () async {
      await manager.onSessionStarted();
      manager.onAutoSaveCallback = () async {
        throw StateError('auto-save failed');
      };

      adapter.emitBegan();
      await Future<void>.delayed(shortTimeout * 2);

      expect(manager.state, InterruptionState.autoSaved);
    });

    test('auto-save is idempotent', () async {
      await manager.onSessionStarted();
      var autoSaveCalls = 0;
      manager.onAutoSaveCallback = () async {
        autoSaveCalls++;
      };

      adapter.emitBegan();
      await Future<void>.delayed(shortTimeout * 2);
      await Future<void>.delayed(Duration.zero);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.autoSaved);
      expect(autoSaveCalls, 1);
    });
  });

  group('interruption ended', () {
    test('before timeout cancels timer, transitions to pausedByInterruption',
        () async {
      await manager.onSessionStarted();
      manager.onPauseCallback = () async {};

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('before timeout verifies mic is available', () async {
      await manager.onSessionStarted();
      adapter.verifyAvailableResult = true;

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('before timeout when mic unavailable still transitions to '
        'pausedByInterruption', () async {
      await manager.onSessionStarted();
      adapter.verifyAvailableResult = false;

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('verifyMicAvailable failure is caught', () async {
      await manager.onSessionStarted();
      adapter.verifyError = StateError('verify failed');

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('after timeout does not double-transition (timer already fired)',
        () async {
      await manager.onSessionStarted();
      manager.onAutoSaveCallback = () async {};
      manager.onPauseCallback = () async {};

      adapter.emitBegan();
      await Future<void>.delayed(shortTimeout * 2);
      expect(manager.state, InterruptionState.autoSaved);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.autoSaved);
    });

    test('received without a prior began is ignored', () async {
      await manager.onSessionStarted();
      expect(manager.state, InterruptionState.active);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.active);
    });

    test('with shouldResume does not verify mic', () async {
      await manager.onSessionStarted();

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      adapter.verifyAvailableResult = false;
      adapter.emitEnded(shouldResume: true);
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
    });
  });

  group('finish-in-progress suppression', () {
    test('began event is ignored when finish is in progress', () async {
      await manager.onSessionStarted();
      manager.onPauseCallback = () async {};

      manager.setFinishInProgress(true);
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.active);
    });

    test('ended event is ignored when finish is in progress', () async {
      await manager.onSessionStarted();

      manager.setFinishInProgress(true);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.active);
    });

    test('events are processed after finish is cleared', () async {
      await manager.onSessionStarted();
      manager.onPauseCallback = () async {};

      manager.setFinishInProgress(true);
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.active);

      manager.setFinishInProgress(false);
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.interrupted);
    });

    test('events ignored when no active session', () async {
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.idle);
    });

    test('began ignored when already pausedByInterruption', () async {
      await manager.onSessionStarted();
      manager.onPauseCallback = () async {};

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
    });
  });

  group('onResumed', () {
    test('transitions from pausedByInterruption to active', () async {
      await manager.onSessionStarted();
      manager.onPauseCallback = () async {};

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      await manager.onResumed();

      expect(manager.state, InterruptionState.active);
    });

    test('no-op when not pausedByInterruption', () async {
      await manager.onSessionStarted();
      expect(manager.state, InterruptionState.active);

      await manager.onResumed();

      expect(manager.state, InterruptionState.active);
    });

    test('no-op when idle', () async {
      expect(manager.state, InterruptionState.idle);

      await manager.onResumed();

      expect(manager.state, InterruptionState.idle);
    });
  });

  group('state changes stream', () {
    test('emits every state transition', () async {
      final states = <InterruptionState>[];
      manager.stateChanges.listen(states.add);

      await manager.onSessionStarted();
      manager.onPauseCallback = () async {};
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      await manager.onResumed();
      await manager.onSessionEnded();
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        InterruptionState.active,
        InterruptionState.interrupted,
        InterruptionState.pausedByInterruption,
        InterruptionState.active,
        InterruptionState.idle,
      ]);
    });
  });

  group('dispose', () {
    test('stops listening and closes controller', () async {
      await manager.onSessionStarted();
      await manager.dispose();

      expect(adapter.stopWasCalled, isTrue);
    });

    test('prevents subsequent state transitions', () async {
      await manager.dispose();
      final states = <InterruptionState>[];
      manager.stateChanges.listen(states.add);

      await manager.onSessionStarted();

      expect(manager.state, InterruptionState.idle);
      expect(states, isEmpty);
    });

    test('double dispose is safe', () async {
      await manager.onSessionStarted();
      await manager.dispose();
      await manager.dispose();

      expect(adapter.stopWasCalled, isTrue);
    });
  });

  group('concurrent start/end', () {
    test('onSessionEnded awaits pending start transition', () async {
      final completer = Completer<void>();
      adapter.startError = null;
      final slowAdapter = _SlowStartAdapter(completer.future);
      final mgr = MicrophoneInterruptionManager(adapter: slowAdapter);

      unawaited(mgr.onSessionStarted());
      await Future<void>.delayed(Duration.zero);

      expect(slowAdapter.startWasCalled, isTrue);
      expect(mgr.state, InterruptionState.active);

      final endFuture = mgr.onSessionEnded();
      await Future<void>.delayed(Duration.zero);

      expect(mgr.state, InterruptionState.active);

      completer.complete();
      await endFuture;

      expect(mgr.state, InterruptionState.idle);
      await mgr.dispose();
    });
  });
}

class _SlowStartAdapter implements MicrophoneInterruptionAdapter {
  _SlowStartAdapter(this._delay);
  final Future<void> _delay;
  bool startWasCalled = false;

  final _eventsController =
      StreamController<InterruptionEvent>.broadcast();

  @override
  Future<void> startListening() async {
    startWasCalled = true;
    await _delay;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<bool> verifyMicAvailable() async => true;

  @override
  Stream<InterruptionEvent> get interruptionEvents =>
      _eventsController.stream;
}
