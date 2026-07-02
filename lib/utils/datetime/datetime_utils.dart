import 'package:intl/intl.dart';

class DateTimeUtils {
  static String formatSmartTimestamp(DateTime dateTime) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final inputDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('h:mm a');
    final fullDateFormat = DateFormat('MMM d, yyyy');

    String time = timeFormat.format(dateTime);

    // 🟢 Today
    if (inputDate == today) {
      return 'Today • $time';
    }

    // 🟡 Yesterday
    if (inputDate == yesterday) {
      return 'Yesterday • $time';
    }

    // 🔵 Within last 7 days → show weekday
    final difference = today.difference(inputDate).inDays;
    if (difference >= 2 && difference < 7) {
      final weekday = DateFormat('EEEE').format(dateTime); // Monday, Tuesday...
      return '$weekday • $time';
    }

    // ⚪ Older than 7 days → absolute date
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

  static String formatDurationFromSeconds(int seconds) {
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
