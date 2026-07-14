import 'package:flutter/services.dart';

/// Parsed `version:` / build fields from a pubspec snippet.
class AppVersionFields {
  const AppVersionFields({
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;
}

/// App version from [pubspec.yaml] (bundled as an asset).
abstract final class AppVersion {
  static String version = '0.0.0';
  static String buildNumber = '0';

  static String get fullLabel => '$version (Build $buildNumber)';

  /// Matches Flutter/Dart pubspec versions:
  /// `1.0.0`, `1.0.0+3`, `1.0.0-beta.7`, `1.0.0-beta.7+42`.
  static final _versionPattern = RegExp(
    r'^version:\s*'
    r'([0-9]+(?:\.[0-9]+)*(?:-[0-9A-Za-z.-]+)?)'
    r'(?:\+(\d+))?'
    r'\s*$',
    multiLine: true,
  );

  static Future<void> init() async {
    final content = await rootBundle.loadString('pubspec.yaml');
    final parsed = parse(content);
    if (parsed == null) return;

    version = parsed.version;
    buildNumber = parsed.buildNumber;
  }

  /// Parses the first `version:` line from [pubspecContent], or `null` if none.
  static AppVersionFields? parse(String pubspecContent) {
    final match = _versionPattern.firstMatch(pubspecContent);
    if (match == null) return null;

    return AppVersionFields(
      version: match.group(1)!,
      buildNumber: match.group(2) ?? '0',
    );
  }
}
