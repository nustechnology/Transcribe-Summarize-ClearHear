import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';

class DateTimeUtils {
  static String formatSmartTimestamp(DateTime dateTime,
      {bool isFullDateFormat = false}) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final inputDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('h:mm a');
    final fullDateFormat = DateFormat('MMM d, yyyy');

    String time = timeFormat.format(dateTime);

    if (isFullDateFormat) {
      final date = fullDateFormat.format(dateTime);
      return '$date • $time';
    }

    // Today
    if (inputDate == today) {
      return '${StringKeys.datetimeToday.tr} • $time';
    }

    // Yesterday
    if (inputDate == yesterday) {
      return '${StringKeys.datetimeYesterday.tr} • $time';
    }

    // Within last 7 days → show weekday
    final difference = today.difference(inputDate).inDays;
    if (difference >= 2 && difference < 7) {
      final weekday = DateFormat('EEEE').format(dateTime); // Monday, Tuesday...
      return '$weekday • $time';
    }

    // Older than 7 days → absolute date
    final date = fullDateFormat.format(dateTime);
    return '$date • $time';
  }

  static String formatTime(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  static String formatDurationFromSeconds(int? seconds) {
    if (seconds == null) return "-";
    final duration = Duration(seconds: seconds);

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(secs)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(secs)}';
    }
  }
}
