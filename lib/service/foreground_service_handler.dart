import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ForegroundServiceHandler {
  static const _channel = MethodChannel('clearhear/foreground_service');

  static bool get _isAndroid => Platform.isAndroid;

  static Future<void> start() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('start');
    } catch (e) {
      debugPrint('[ForegroundService] start failed: $e');
    }
  }

  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[ForegroundService] stop failed: $e');
    }
  }
}
