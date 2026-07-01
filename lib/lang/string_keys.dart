import 'package:get/get.dart';

/// Translation key constants. Use with GetX: `StringKeys.appTitle.tr`
abstract class StringKeys {
  StringKeys._();

  static const appTitle = 'app_title';
  static const homeStatusIdle = 'home_status_idle';
  static const homeStatusActive = 'home_status_active';
  static const homeSpeakerLabel = 'home_speaker_label';
  static const homePlaceholderTranscript = 'home_placeholder_transcript';
  static const homeIdlePrompt = 'home_idle_prompt';
  static const homeStartCaptioning = 'home_start_captioning';
  static const homeStopCaptioning = 'home_stop_captioning';
  static const homeStop = 'home_stop';
  static const homeListening = 'home_listening';
  static const homeProcessing = 'home_processing';
  static const homeSummaryLabel = 'home_summary_label';
  static const microphonePermissionDenied = 'microphone_permission_denied';
  static const transcriptionFailed = 'transcription_failed';
  static const summaryFailed = 'summary_failed';
  static const summaryModelFailed = 'summary_model_failed';
  static const recorderUnavailable = 'recorder_unavailable';
  static const navLive = 'nav_live';
  static const navHistory = 'nav_history';
  static const navSettings = 'nav_settings';
  static const homeLanguageEnglish = 'home_language_english';
  static const homeConfidenceLabel = 'home_confidence_label';
  static const homeConfidenceMedium = 'home_confidence_medium';
  static const homePrivacyNote = 'home_privacy_note';
  static const homeFontDecrease = 'home_font_decrease';
  static const homeFontIncrease = 'home_font_increase';
  static const homeSummarize = 'home_summarize';

  static String t(String key) => key.tr;
}
