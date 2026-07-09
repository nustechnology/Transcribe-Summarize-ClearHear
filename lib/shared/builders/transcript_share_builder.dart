import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';
import 'package:transcribe_summarize_clearhear/shared/models/session_model.dart';

class TranscriptShareBuilder {
  const TranscriptShareBuilder._();

  static String build({
    required SessionModel session,
    required List<SegmentModel> segments,
  }) {
    final transcript = segments.isEmpty
        ? noTranscriptFallback()
        : segments.map(buildSegmentLine).join('\n');

    return '${buildHeader(session)}\n$transcript';
  }

  static String buildHeader(SessionModel session) {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      session.startedAt * 1000,
    );

    final date = DateFormat(
      'MMM d, yyyy • h:mm a',
      'en_US',
    ).format(startedAt);

    final duration = _formatDuration(session.durationSec);

    final summary = session.summary?.trim().isNotEmpty == true
        ? session.summary!.trim()
        : _translatedOrDefault(
            StringKeys.historyDetailPlaceholderSummary,
            'No summary is available for this file.',
          );

    return '${session.title}\n'
        '${StringKeys.transcriptHeaderDate.tr}: $date ${StringKeys.transcriptHeaderDuration.tr}: $duration\n\n'
        '${StringKeys.transcriptHeaderSummary.tr}\n'
        '$summary\n\n'
        '${StringKeys.transcriptHeaderFullTranscript.tr}';
  }

  static String buildSegmentLine(SegmentModel segment) {
    return '[${_formatDuration(segment.startMs ~/ 1000)}] ${segment.text}';
  }

  static String noTranscriptFallback() {
    return _translatedOrDefault(
      StringKeys.historyDetailNoTranscript,
      'No transcript is available yet.',
    );
  }

  static String _formatDuration(int? seconds) {
    if (seconds == null) {
      return '-';
    }

    final duration = Duration(seconds: seconds);

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(secs)}';
    }

    return '${twoDigits(minutes)}:${twoDigits(secs)}';
  }

  static String _translatedOrDefault(String key, String fallback) {
    final translated = key.tr;
    return translated == key ? fallback : translated;
  }
}
