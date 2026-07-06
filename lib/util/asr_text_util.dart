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
