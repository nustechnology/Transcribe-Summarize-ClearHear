import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/service/interruption/microphone_interruption_adapter.dart';
import 'package:transcribe_summarize_clearhear/service/interruption/microphone_interruption_manager.dart';

class FakeInterruptionAdapter implements MicrophoneInterruptionAdapter {
  final _eventController = StreamController<InterruptionEvent>.broadcast();

  bool isListening = false;
  bool verifyResult = true;
  int startCount = 0;
  int stopCount = 0;
  int verifyCallCount = 0;
  List<bool>? verifyResults;

  void emit(InterruptionEvent event) => _eventController.add(event);

  void emitBegan() =>
      _eventController.add(const InterruptionEvent(InterruptionEventType.began));

  void emitEnded({bool? shouldResume}) =>
      _eventController.add(InterruptionEvent(
        InterruptionEventType.ended,
        shouldResume: shouldResume,
      ));

  @override
  Stream<InterruptionEvent> get interruptionEvents => _eventController.stream;

  @override
  Future<void> startListening() async {
    startCount++;
    isListening = true;
  }

  @override
  Future<void> stopListening() async {
    stopCount++;
    isListening = false;
  }

  @override
  Future<bool> verifyMicAvailable() async {
    verifyCallCount++;
    if (verifyResults != null && verifyResults!.isNotEmpty) {
      final idx = (verifyCallCount - 1).clamp(0, verifyResults!.length - 1);
      return verifyResults![idx];
    }
    return verifyResult;
  }
}

void main() {
  late FakeInterruptionAdapter adapter;
  late MicrophoneInterruptionManager manager;

  setUp(() {
    adapter = FakeInterruptionAdapter();
    manager = MicrophoneInterruptionManager(
      adapter: adapter,
      timeoutDuration: const Duration(milliseconds: 100),
    );
  });

  tearDown(() async {
    await manager.dispose();
  });

  group('State transitions', () {
    test('starts in idle state', () {
      expect(manager.state, InterruptionState.idle);
    });

    test('transitions from active to interrupted on interruption began', () async {
      final states = <InterruptionState>[];
      manager.stateChanges.listen(states.add);

      manager.onSessionStarted();
      expect(manager.state, InterruptionState.active);

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.interrupted);
      expect(states, [
        InterruptionState.active,
        InterruptionState.interrupted,
      ]);
    });

    test('transitions from interrupted to pausedByInterruption on recovery', () async {
      final states = <InterruptionState>[];
      manager.stateChanges.listen(states.add);

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
      expect(states, [
        InterruptionState.active,
        InterruptionState.interrupted,
        InterruptionState.pausedByInterruption,
      ]);
    });

    test('transitions back to active on manual resume', () async {
      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      await manager.onResumed();
      expect(manager.state, InterruptionState.active);
    });

    test('onResumed is a no-op if not in pausedByInterruption', () async {
      manager.onSessionStarted();
      expect(manager.state, InterruptionState.active);

      await manager.onResumed();
      expect(manager.state, InterruptionState.active);
    });
  });

  group('Timeout', () {
    test('auto-saves when interruption duration exceeds timeout', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(autoSaveCalled, isTrue);
      expect(manager.state, InterruptionState.autoSaved);
    });

    test('does not auto-save when interruption ends before timeout', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(autoSaveCalled, isFalse);
      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('short recovery stays pausedByInterruption even after waiting', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(autoSaveCalled, isFalse);
      expect(manager.state, InterruptionState.pausedByInterruption);
    });
  });

  group('Edge cases', () {
    test('ignores interruption events when idle', () async {
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.idle);
    });

    test('ignores interruption events when finish is in progress', () async {
      manager.onSessionStarted();
      manager.setFinishInProgress(true);
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.active);
    });

    test('ignores duplicate interruption began when already pausedByInterruption', () async {
      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('remains pausedByInterruption when mic not available on recovery', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      adapter.verifyResult = false;
      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(autoSaveCalled, isFalse);
      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('onSessionEnded transitions to idle', () {
      manager.onSessionStarted();
      expect(manager.state, InterruptionState.active);
      manager.onSessionEnded();
      expect(manager.state, InterruptionState.idle);
    });
  });

  group('Lifecycle', () {
    test('starts listening on session started', () {
      manager.onSessionStarted();
      expect(adapter.startCount, 1);
      expect(adapter.isListening, isTrue);
    });

    test('stops listening on session ended', () {
      manager.onSessionStarted();
      manager.onSessionEnded();
      expect(adapter.stopCount, 1);
      expect(adapter.isListening, isFalse);
    });

    test('dispose cleans up listener', () async {
      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      await manager.dispose();
      expect(adapter.stopCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      await expectLater(manager.stateChanges, neverEmits(anything));
    });
  });

  group('Callbacks', () {
    test('onPauseCallback is called on interruption began', () async {
      var pauseCalled = false;
      manager.onPauseCallback = () async {
        pauseCalled = true;
      };

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      expect(pauseCalled, isTrue);
      expect(manager.state, InterruptionState.interrupted);
    });
  });

  group('Duration timing', () {
    test('auto-save respects duration regardless of when events fire', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(autoSaveCalled, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(autoSaveCalled, isTrue);
    });
  });

  group('shouldResume flag', () {
    test('shouldResume=true skips verifyMicAvailable and transitions to pausedByInterruption', () async {
      adapter.verifyResult = false;
      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      adapter.emitEnded(shouldResume: true);
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
      expect(adapter.verifyCallCount, 0);
    });

    test('shouldResume=false transitions to pausedByInterruption', () async {
      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);

      adapter.emitEnded(shouldResume: false);
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, InterruptionState.pausedByInterruption);
    });
  });

  group('Recovery without manual resume', () {
    test('stays pausedByInterruption after recovery with mic unavailable', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };
      adapter.verifyResult = false;

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);

      expect(autoSaveCalled, isFalse);
      expect(manager.state, InterruptionState.pausedByInterruption);
    });

    test('short interruption stays pausedByInterruption after recovery with no auto-save later', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(autoSaveCalled, isFalse);
      expect(manager.state, InterruptionState.pausedByInterruption);
    });
  });
}
