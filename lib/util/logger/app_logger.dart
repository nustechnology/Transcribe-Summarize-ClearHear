import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

class AppLogger {
  static final _dateFormat = DateFormat('HH:mm:ss.SSS (yyyy-MM-dd)');

  // ANSI colors
  static const _reset = '\x1B[0m';
  static const _red = '\x1B[31m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';

  static void info(String message, {String tag = 'General'}) {
    if (kDebugMode) {
      _log(
        'INFO',
        '💡 $message',
        tag: tag,
        color: _green,
      );
    }
  }

  static void warning(String message, {String tag = 'General'}) {
    if (kDebugMode) {
      _log(
        'WARN',
        '⚠️ $message',
        tag: tag,
        color: _yellow,
      );
    }
  }

  static void error({
    String? message,
    Object? error,
    StackTrace? stackTrace,
    String tag = 'General',
  }) {
    if (kDebugMode) {
      final errorMessage = '⛔ ${message ?? 'An error occurred'}';
      _log(
        'ERROR',
        errorMessage,
        tag: tag,
        color: _red,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _log(
    String level,
    String message, {
    required String tag,
    required String color,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = _dateFormat.format(DateTime.now());
    final lines = message.trim().split('\n');

    // Header
    developer.log(
      '$color╔════════════════════════════════════════════════════════════════╗',
      name: tag,
      level: _mapLevel(level),
    );

    developer.log(
      '${'║ [$level] $timestamp [$tag]'.padRight(66)}║',
      name: tag,
      level: _mapLevel(level),
    );

    for (final line in lines) {
      developer.log(
        '${'║ → $line'.padRight(66)}║',
        name: tag,
        level: _mapLevel(level),
      );
    }

    if (error != null) {
      developer.log(
        '${'║ 🟥 Error: $error'.padRight(66)}║',
        name: tag,
        level: _mapLevel('ERROR'),
      );
    }

    if (stackTrace != null) {
      final formattedStack = _formatStackTrace(stackTrace);
      for (final line in formattedStack.split('\n')) {
        developer.log(
          '${'║ 📍 $line'.padRight(66)}║',
          name: tag,
          level: _mapLevel('ERROR'),
        );
      }
    }

    // Footer
    developer.log(
      '╚════════════════════════════════════════════════════════════════╝$_reset',
      name: tag,
      level: _mapLevel(level),
    );
  }

  static int _mapLevel(String level) {
    switch (level.toUpperCase()) {
      case 'INFO':
        return 800; // INFO
      case 'WARN':
        return 900; // WARNING
      case 'ERROR':
        return 1000; // SEVERE
      default:
        return 800;
    }
  }

  static String _formatStackTrace(StackTrace stackTrace, {int maxLines = 3}) {
    final lines = stackTrace.toString().split('\n');
    return lines.take(maxLines).join('\n');
  }
}
