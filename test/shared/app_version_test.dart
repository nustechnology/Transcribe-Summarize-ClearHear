import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/app_version.dart';

void main() {
  group('AppVersion.parse', () {
    test('parses stable version with build number', () {
      final parsed = AppVersion.parse('''
name: demo
version: 1.0.0+3
''');

      expect(parsed, isNotNull);
      expect(parsed!.version, '1.0.0');
      expect(parsed.buildNumber, '3');
    });

    test('parses stable version without build number', () {
      final parsed = AppVersion.parse('version: 2.1.4\n');

      expect(parsed, isNotNull);
      expect(parsed!.version, '2.1.4');
      expect(parsed.buildNumber, '0');
    });

    test('parses prerelease version without build number', () {
      final parsed = AppVersion.parse('version: 1.0.0-beta.7\n');

      expect(parsed, isNotNull);
      expect(parsed!.version, '1.0.0-beta.7');
      expect(parsed.buildNumber, '0');
    });

    test('parses prerelease version with build number', () {
      final parsed = AppVersion.parse('''
# comment
version: 1.0.0-beta.7+42
description: sample
''');

      expect(parsed, isNotNull);
      expect(parsed!.version, '1.0.0-beta.7');
      expect(parsed.buildNumber, '42');
    });

    test('parses alpha / rc style prerelease identifiers', () {
      final parsed = AppVersion.parse('version: 3.2.1-rc.1+9\n');

      expect(parsed, isNotNull);
      expect(parsed!.version, '3.2.1-rc.1');
      expect(parsed.buildNumber, '9');
    });

    test('returns null when version line is missing or invalid', () {
      expect(AppVersion.parse('name: demo\n'), isNull);
      expect(AppVersion.parse('version: not-a-version\n'), isNull);
    });
  });
}
