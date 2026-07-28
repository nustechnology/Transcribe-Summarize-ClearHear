import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'microphone_interruption_adapter.dart';

class IosInterruptionAdapter implements MicrophoneInterruptionAdapter {
  static const _channel = MethodChannel('clearhear/audio_interruption');

  final _eventController = StreamController<InterruptionEvent>.broadcast();

  bool _isListening = false;

  @override
  Stream<InterruptionEvent> get interruptionEvents => _eventController.stream;

  @override
  Future<void> startListening() async {
    if (_isListening) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    try {
      await _channel.invokeMethod('startListening');
      _isListening = true;
    } catch (_) {
      _channel.setMethodCallHandler(null);
      rethrow;
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
    _isListening = false;
  }

  @override
  Future<bool> verifyMicAvailable() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) return false;
    return true;
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onInterruptionBegan':
        _eventController.add(const InterruptionEvent(InterruptionEventType.began));
      case 'onInterruptionEnded':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final shouldResume = args?['shouldResume'] as bool?;
        _eventController.add(
          InterruptionEvent(InterruptionEventType.ended, shouldResume: shouldResume),
        );
    }
  }
}
