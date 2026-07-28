import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';

import 'microphone_interruption_adapter.dart';

class AndroidInterruptionAdapter implements MicrophoneInterruptionAdapter {
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
      final granted = await _channel.invokeMethod<bool>('startListening');
      _isListening = granted ?? false;
      if (!_isListening) {
        AppLogger.warning(
          'Audio focus request denied; interruption detection inactive',
          tag: 'AndroidInterruptionAdapter',
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        message: 'Failed to start listening for audio interruptions',
        error: error,
        stackTrace: stackTrace,
        tag: 'AndroidInterruptionAdapter',
      );
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod('stopListening');
    } catch (error, stackTrace) {
      AppLogger.error(
        message: 'Failed to stop listening for audio interruptions',
        error: error,
        stackTrace: stackTrace,
        tag: 'AndroidInterruptionAdapter',
      );
    }
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
        break;
      case 'onInterruptionEnded':
        _eventController.add(const InterruptionEvent(InterruptionEventType.ended));
        break;
    }
  }
}
