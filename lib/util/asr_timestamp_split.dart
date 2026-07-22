import 'asr_text_util.dart';

/// Splits ASR output at a cut time within the current utterance.
///
/// Prefers per-token [timestamps] (seconds from utterance start). Falls back
/// to splitting [fullText] at the nearest space using a duration ratio when
/// timestamps are missing or misaligned.
({String prefix, String suffix}) splitAsrTextAtCutSeconds({
  required String fullText,
  required List<String> tokens,
  required List<double> timestamps,
  required double cutSeconds,
  double? utteranceDurationSeconds,
}) {
  final trimmed = fullText.trim();
  if (trimmed.isEmpty || cutSeconds <= 0) {
    return (prefix: '', suffix: formatAsrText(trimmed));
  }

  if (tokens.isNotEmpty &&
      timestamps.length == tokens.length &&
      timestamps.any((t) => t > 0)) {
    final prefixTokens = <String>[];
    final suffixTokens = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      if (timestamps[i] <= cutSeconds) {
        prefixTokens.add(tokens[i]);
      } else {
        suffixTokens.add(tokens[i]);
      }
    }
    return (
      prefix: formatAsrText(joinAsrTokens(prefixTokens)),
      suffix: formatAsrText(joinAsrTokens(suffixTokens)),
    );
  }

  final duration = utteranceDurationSeconds ?? 0;
  if (duration <= 0 || cutSeconds >= duration) {
    return (prefix: formatAsrText(trimmed), suffix: '');
  }

  final ratio = (cutSeconds / duration).clamp(0.0, 1.0);
  var splitAt = (trimmed.length * ratio).round().clamp(0, trimmed.length);

  // Prefer a word boundary near the proportional cut.
  if (splitAt > 0 && splitAt < trimmed.length) {
    final spaceBefore = trimmed.lastIndexOf(' ', splitAt);
    final spaceAfter = trimmed.indexOf(' ', splitAt);
    if (spaceBefore > 0 && splitAt - spaceBefore <= 12) {
      splitAt = spaceBefore;
    } else if (spaceAfter > 0 && spaceAfter - splitAt <= 12) {
      splitAt = spaceAfter;
    }
  }

  final prefix = trimmed.substring(0, splitAt).trim();
  final suffix = trimmed.substring(splitAt).trim();
  return (prefix: formatAsrText(prefix), suffix: formatAsrText(suffix));
}

/// Joins streaming ASR / SentencePiece-style tokens into plain text.
///
/// Leading `▁` or space marks a word boundary.
String joinAsrTokens(List<String> tokens) {
  if (tokens.isEmpty) return '';

  final buffer = StringBuffer();
  for (final raw in tokens) {
    var token = raw;
    var wordBreak = false;
    if (token.startsWith('▁')) {
      wordBreak = true;
      token = token.substring(1);
    } else if (token.startsWith(' ')) {
      wordBreak = true;
      token = token.trimLeft();
    }
    if (token.isEmpty) continue;
    if (wordBreak && buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(token);
  }
  return buffer.toString();
}
