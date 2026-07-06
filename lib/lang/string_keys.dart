import 'package:get/get.dart';

/// Translation key constants. Use with GetX: `StringKeys.appTitle.tr`
abstract class StringKeys {
  StringKeys._();

  static const appTitle = 'app_title';
  static const homeStatusIdle = 'home_status_idle';
  static const homeStatusActive = 'home_status_active';
  static const homeSpeakerLabel = 'home_speaker_label';
  static const homePlaceholderTranscript = 'home_placeholder_transcript';
  static const homeIdlePromptLine1 = 'home_idle_prompt_line1';
  static const homeIdlePromptLine2 = 'home_idle_prompt_line2';
  static const homeStartCaptioning = 'home_start_captioning';
  static const homeStopCaptioning = 'home_stop_captioning';
  static const homeStop = 'home_stop';
  static const homeListening = 'home_listening';
  static const homeProcessing = 'home_processing';
  static const homeSummaryLabel = 'home_summary_label';
  static const microphonePermissionDenied = 'microphone_permission_denied';
  static const transcriptionFailed = 'transcription_failed';
  static const transcriptionModelFailed = 'transcription_model_failed';
  static const summaryFailed = 'summary_failed';
  static const summaryModelFailed = 'summary_model_failed';
  static const recorderUnavailable = 'recorder_unavailable';
  static const navLive = 'nav_live';
  static const navHistory = 'nav_history';
  static const navSettings = 'nav_settings';
  static const homeLanguageEnglish = 'home_language_english';
  static const homeConfidenceLabel = 'home_confidence_label';
  static const homeConfidenceMedium = 'home_confidence_medium';
  static const homePrivacyOnDevice = 'home_privacy_on_device';
  static const homePrivacyNotStored = 'home_privacy_not_stored';
  static const homeFontDecrease = 'home_font_decrease';
  static const homeFontIncrease = 'home_font_increase';
  static const homeStatusListening = 'home_status_listening';
  static const homeSpeaker1 = 'home_speaker_1';
  static const homeSpeaker2 = 'home_speaker_2';
  static const homeDemoTranscript1 = 'home_demo_transcript_1';
  static const homeDemoTranscript2 = 'home_demo_transcript_2';
  static const homeDemoTranscriptPending = 'home_demo_transcript_pending';
  static const homeDemoTime = 'home_demo_time';
  static const homeConfidenceHigh = 'home_confidence_high';
  static const navSummary = 'nav_summary';
  static const homeSummarize = 'home_summarize';

  static String t(String key) => key.tr;
}
