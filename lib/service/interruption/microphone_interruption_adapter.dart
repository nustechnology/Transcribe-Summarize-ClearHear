import 'dart:async';

enum InterruptionEventType { began, ended }

class InterruptionEvent {
  final InterruptionEventType type;
  final bool? shouldResume;

  const InterruptionEvent(this.type, {this.shouldResume});
}

abstract class MicrophoneInterruptionAdapter {
  Future<void> startListening();
  Future<void> stopListening();
  Future<bool> verifyMicAvailable();

  Stream<InterruptionEvent> get interruptionEvents;
}
