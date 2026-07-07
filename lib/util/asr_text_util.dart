/// Blank line between utterance segments in the transcript view.
const segmentTextSeparator = '\n\n';

/// Joins non-empty segment texts with a visible gap between each one.
String joinSegmentTexts(Iterable<String> texts) {
  return texts
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .join(segmentTextSeparator);
}

/// Splits a combined transcript back into individual segments.
List<String> splitSegmentTexts(String transcript) {
  if (transcript.trim().isEmpty) return const [];

  return transcript
      .split(segmentTextSeparator)
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .toList(growable: false);
}

/// Normalizes ASR output (often ALL CAPS from English models).
String formatAsrText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;

  final lower = trimmed.toLowerCase();
  final buffer = StringBuffer();
  var capitalizeNext = true;

  for (var i = 0; i < lower.length; i++) {
    final char = lower[i];
    if (capitalizeNext && _isAsciiLetter(char)) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
    } else {
      buffer.write(char);
    }

    if (char == '.' || char == '!' || char == '?') {
      capitalizeNext = true;
    }
  }

  return buffer.toString();
}

bool _isAsciiLetter(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

/// Formats a segment timestamp as `HH:mm:ss AM/PM`.
String formatSegmentClockTime(DateTime time) {
  final hour24 = time.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour = hour12.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second $period';
}
