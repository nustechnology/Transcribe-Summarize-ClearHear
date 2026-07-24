import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/service/interruption/microphone_interruption_adapter.dart';
import 'package:transcribe_summarize_clearhear/service/interruption/microphone_interruption_manager.dart';

class FakeInterruptionAdapter implements MicrophoneInterruptionAdapter {
  final _eventController = StreamController<InterruptionEvent>.broadcast();

  bool verifyResult = true;
  int startCount = 0;
  int stopCount = 0;

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
  }

  @override
  Future<void> stopListening() async {
    stopCount++;
  }

  @override
  Future<bool> verifyMicAvailable() async => verifyResult;
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

  tearDown(() {
    manager.dispose();
  });

  group('End-to-end interruption flows', () {
    test('interruption → recovery → resume → normal stop', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      expect(manager.state, InterruptionState.active);

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      await manager.onResumed();
      expect(manager.state, InterruptionState.active);

      manager.onSessionEnded();
      expect(manager.state, InterruptionState.idle);

      expect(adapter.stopCount, 1);
      expect(autoSaveCalled, isFalse);
    });

    test('interruption → long duration → auto-save on ended', () async {
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

    test('permission denied on recovery → stays pausedByInterruption, no auto-save', () async {
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

    test('interruption during ongoing session → user discards → no auto-save', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      manager.onSessionEnded();
      expect(manager.state, InterruptionState.idle);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(autoSaveCalled, isFalse);
    });

    test('multiple interruptions in one session', () async {
      manager.onSessionStarted();

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      await manager.onResumed();
      expect(manager.state, InterruptionState.active);

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.interrupted);

      adapter.emitEnded();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.pausedByInterruption);

      await manager.onResumed();
      expect(manager.state, InterruptionState.active);

      manager.onSessionEnded();
      expect(manager.state, InterruptionState.idle);
    });

    test('interruption while finish is in flight → event ignored', () async {
      var autoSaveCalled = false;
      manager.onAutoSaveCallback = () async {
        autoSaveCalled = true;
      };

      manager.onSessionStarted();
      manager.setFinishInProgress(true);

      adapter.emitBegan();
      await Future<void>.delayed(Duration.zero);
      expect(manager.state, InterruptionState.active);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(autoSaveCalled, isFalse);

      manager.setFinishInProgress(false);
      manager.onSessionEnded();
    });
  });
}
