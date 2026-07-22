import 'package:get/get.dart';

/// Translation key constants. Use with GetX: `StringKeys.appTitle.tr`
abstract class StringKeys {
  StringKeys._();

  static const appTitle = 'app_title';
  static const homeStatusIdle = 'home_status_idle';
  static const homeStatusPaused = 'home_status_paused';
  static const homeSpeakerLabel = 'home_speaker_label';
  static const homeSpeakerUnknown = 'home_speaker_unknown';
  static const homeIdlePromptLine1 = 'home_idle_prompt_line1';
  static const homeIdlePromptLine2 = 'home_idle_prompt_line2';
  static const homeStartCaptioning = 'home_start_captioning';
  static const homeLoadingModel = 'home_loading_model';
  static const homeStopCaptioning = 'home_stop_captioning';
  static const homeStopCaptioningPaused = 'home_stop_captioning_paused';
  static const homeResumeCaptioning = 'home_resume_captioning';
  static const homeListening = 'home_listening';
  static const homeProcessing = 'home_processing';
  static const homeSummaryLabel = 'home_summary_label';
  static const microphonePermissionDenied = 'microphone_permission_denied';
  static const microphonePermissionMessage = 'microphone_permission_message';
  static const microphonePermissionCancel = 'microphone_permission_cancel';
  static const microphonePermissionOpenSettings =
      'microphone_permission_open_settings';
  static const transcriptionFailed = 'transcription_failed';
  static const transcriptionModelFailed = 'transcription_model_failed';
  static const homeTranscriptTooShortTitle = 'home_transcript_too_short_title';
  static const homeTranscriptTooShortMessage =
      'home_transcript_too_short_message';
  static const homeTranscriptUnrecognizedTitle =
      'home_transcript_unrecognized_title';
  static const homeTranscriptUnrecognizedMessage =
      'home_transcript_unrecognized_message';
  static const homeTranscriptFailedTitle = 'home_transcript_failed_title';
  static const commonOk = 'common_ok';
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
  static const homeConfidenceHigh = 'home_confidence_high';
  static const historySearchHint = 'history_search_hint';
  static const historyNoResults = 'history_no_results';
  static const historyNoMatchingSessions = 'history_no_matching_sessions';
  static const historySecureNote = 'history_secure_note';
  static const historyItemsSelected = 'history_items_selected';
  static const historySelectAll = 'history_select_all';
  static const historyDeselectAll = 'history_deselect_all';
  static const historyCancel = 'history_cancel';
  static const historyDeleteConfirmTitle = 'history_delete_confirm_title';
  static const historyDeleteConfirmMessage = 'history_delete_confirm_message';
  static const historyDeleteConfirmAction = 'history_delete_confirm_action';
  static const historyDeleteSuccess = 'history_delete_success';
  static const historyDeleteRemovedNote = 'history_delete_removed_note';
  static const historyDetailShare = 'history_detail_share';
  static const commonRetry = 'commonRetry';
  static const commonRetrying = 'commonRetrying';
  static const historyDetailSummaryLabel = 'history_detail_summary_label';
  static const historyDetailNoTranscript = 'history_detail_no_transcript';
  static const historyDetailOnDevice = 'history_detail_on_device';
  static const historyDetailPrivate = 'history_detail_private';
  static const historyDetailPlaceholderSummary =
      'history_detail_placeholder_summary';
  static const historyDetailGeneratingSummary =
      'history_detail_generating_summary';
  static const historyDetailSummaryFailed = 'history_detail_summary_failed';
  static const historyDetailSummaryFailedResource =
      'history_detail_summary_failed_resource';
  static const transcriptHeaderDate = 'transcript_header_date';
  static const transcriptHeaderDuration = 'transcript_header_duration';
  static const transcriptHeaderSummary = 'transcript_header_summary';
  static const transcriptHeaderFullTranscript =
      'transcript_header_full_transcript';
  static const historyDetailDeleteSuccess = 'history_detail_delete_success';
  static const historyDetailShareFailed = 'history_detail_share_failed';
  static const sessionDetailDeleteConfirmTitle =
      'session_detail_delete_confirm_title';
  static const sessionDetailDeleteConfirmMessage =
      'session_detail_delete_confirm_message';
  static const sessionDetailDeleteConfirmCancel =
      'session_detail_delete_confirm_cancel';
  static const sessionDetailDeleteConfirmDelete =
      'session_detail_delete_confirm_delete';
  static const datetimeToday = 'datetime_today';
  static const datetimeYesterday = 'datetime_yesterday';
  static const somethingWentWrong = 'something_went_wrong';

  static const homeSaveSessionTitle = 'home_save_session_title';
  static const homeSaveSessionDuration = 'home_save_session_duration';
  static const homeSaveSessionTitleHint = 'home_save_session_title_hint';
  static const homeSaveSessionDefaultTitle = 'home_save_session_default_title';
  static const homeSaveSessionAutoTitle = 'home_save_session_auto_title';
  static const homeSaveSessionDiscard = 'home_save_session_discard';
  static const homeSaveSessionSave = 'home_save_session_save';
  static const homeSaveSessionSuccess = 'home_save_session_success';
  static const homeSaveSessionDurationMinutes = 'home_save_session_duration_minutes';
  static const homeSaveSessionDurationSeconds = 'home_save_session_duration_seconds';
  static const homeSaveSessionDurationOneMinute = 'home_save_session_duration_one_minute';
  static const homeSaveSessionStoredNote = 'home_save_session_stored_note';
  static const settingsDisplay = 'settings_display';
  static const settingsCaptionSize = 'settings_caption_size';
  static const settingsCaptionSizeHint = 'settings_caption_size_hint';
  static const settingsCaptionSizeValue = 'settings_caption_size_value';
  static const settingsPrivacy = 'settings_privacy';
  static const settingsSaveTranscripts = 'settings_save_transcripts';
  static const settingsSaveTranscriptsHint = 'settings_save_transcripts_hint';
  static const settingsClearAllData = 'settings_clear_all_data';
  static const settingsClearAllDataHint = 'settings_clear_all_data_hint';
  static const settingsErase = 'settings_erase';
  static const settingsClearDataConfirmTitle = 'settings_clear_data_confirm_title';
  static const settingsClearDataConfirmMessage = 'settings_clear_data_confirm_message';
  static const settingsClearDataSuccess = 'settings_clear_data_success';
  static const settingsAbout = 'settings_about';
  static const settingsAboutDescription = 'settings_about_description';
  static const settingsHelpSupport = 'settings_help_support';
  static const settingsHelpSupportBody = 'settings_help_support_body';
  static const settingsVersion = 'settings_version';
  static const settingsDone = 'settings_done';
  static const settingsDevelopment = 'settings_development';
  static const settingsDevelopmentTools = 'settings_development_tools';
  static const settingsDevelopmentToolsHint = 'settings_development_tools_hint';
  static const devScreenTitle = 'dev_screen_title';
  static const devTranscriptInputLabel = 'dev_transcript_input_label';
  static const devTranscriptInputHint = 'dev_transcript_input_hint';
  static const devClippedPreviewLabel = 'dev_clipped_preview_label';
  static const devClippedPreviewEmpty = 'dev_clipped_preview_empty';
  static const devSummarizeButton = 'dev_summarize_button';
  static const devSummarizeRunning = 'dev_summarize_running';

  static String t(String key) => key.tr;
}
