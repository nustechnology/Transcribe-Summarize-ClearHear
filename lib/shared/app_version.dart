/// App version metadata mirrored from [pubspec.yaml].
abstract final class AppVersion {
  static const version = '1.0.0';
  static const buildNumber = '1';

  static String get fullLabel => '$version (Build $buildNumber)';
}
