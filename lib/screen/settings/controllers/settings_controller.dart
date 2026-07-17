import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/route/app_route.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/settings_repository.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/history/controllers/history_controller.dart';
import 'package:transcribe_summarize_clearhear/screen/home/controllers/home_controller.dart';
import 'package:transcribe_summarize_clearhear/shared/app_version.dart';
import 'package:transcribe_summarize_clearhear/shared/caption_size_config.dart';
import 'package:transcribe_summarize_clearhear/shared/models/settings_model.dart';
import 'package:transcribe_summarize_clearhear/util/logger/app_logger.dart';
import 'package:transcribe_summarize_clearhear/util/toast/app_toast.dart';

class SettingsController extends GetxController {
  SettingsController({
    required SettingsRepository settingsRepository,
    required SessionRepository sessionRepository,
  })  : _settingsRepository = settingsRepository,
        _sessionRepository = sessionRepository;

  static const minCaptionSize = CaptionSizeConfig.min;
  static const maxCaptionSize = CaptionSizeConfig.max;
  static const captionSizeStep = CaptionSizeConfig.step;

  final SettingsRepository _settingsRepository;
  final SessionRepository _sessionRepository;

  final captionSize = SettingsModel.defaults().fontSize.obs;
  final saveTranscripts = true.obs;
  final isLoading = true.obs;
  final isClearing = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      isLoading.value = true;
      final settings = await _settingsRepository.loadSettings();
      captionSize.value = settings.fontSize;
      saveTranscripts.value = settings.savingEnabled;
      _syncCaptionSizeToHome(settings.fontSize);
      _syncSaveTranscriptsToHome(settings.savingEnabled);
    } catch (e) {
      AppLogger.error(error: e);
      AppToast.error(StringKeys.somethingWentWrong.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> decreaseCaptionSize() async {
    final next = captionSize.value - captionSizeStep;
    if (next < minCaptionSize) return;
    await _setCaptionSize(next);
  }

  Future<void> increaseCaptionSize() async {
    final next = captionSize.value + captionSizeStep;
    if (next > maxCaptionSize) return;
    await _setCaptionSize(next);
  }

  Future<void> _setCaptionSize(double size) async {
    final previous = captionSize.value;
    captionSize.value = size;
    _syncCaptionSizeToHome(size);
    try {
      await _settingsRepository.updateFontSize(size);
    } catch (e) {
      captionSize.value = previous;
      _syncCaptionSizeToHome(previous);
      AppLogger.error(error: e);
      AppToast.error(StringKeys.somethingWentWrong.tr);
    }
  }

  Future<void> setSaveTranscripts(bool enabled) async {
    final previous = saveTranscripts.value;
    saveTranscripts.value = enabled;
    _syncSaveTranscriptsToHome(enabled);
    try {
      await _settingsRepository.updateSavingEnabled(enabled: enabled);
    } catch (e) {
      saveTranscripts.value = previous;
      _syncSaveTranscriptsToHome(previous);
      AppLogger.error(error: e);
      AppToast.error(StringKeys.somethingWentWrong.tr);
    }
  }

  Future<void> confirmAndClearAllData() async {
    if (isClearing.value) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(StringKeys.settingsClearDataConfirmTitle.tr),
        content: Text(StringKeys.settingsClearDataConfirmMessage.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(StringKeys.historyCancel.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              StringKeys.settingsErase.tr,
              style: const TextStyle(color: Color(0xFFE66754)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await clearAllData();
  }

  Future<void> clearAllData() async {
    if (isClearing.value) return;

    try {
      isClearing.value = true;
      final defaults = SettingsModel.defaults();
      await Future.wait([
        _sessionRepository.deleteAllSessions(),
        _settingsRepository.saveSettings(defaults),
      ]);
      captionSize.value = defaults.fontSize;
      saveTranscripts.value = defaults.savingEnabled;
      _syncCaptionSizeToHome(defaults.fontSize);
      _syncSaveTranscriptsToHome(defaults.savingEnabled);

      if (Get.isRegistered<HistoryController>()) {
        await Get.find<HistoryController>().loadHistory();
      }

      AppToast.success(StringKeys.settingsClearDataSuccess.tr);
    } catch (e) {
      AppLogger.error(error: e);
      AppToast.error(StringKeys.somethingWentWrong.tr);
    } finally {
      isClearing.value = false;
    }
  }

  void openDevelopment() {
    Get.rootDelegate.toNamed(AppRoutes.development);
  }

  void openHelpAndSupport() {
    Get.dialog(
      AlertDialog(
        title: Text(StringKeys.settingsHelpSupport.tr),
        content: Text(StringKeys.settingsHelpSupportBody.tr),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(StringKeys.settingsDone.tr),
          ),
        ],
      ),
    );
  }

  void openVersionInfo() {
    Get.dialog(
      AlertDialog(
        title: Text(StringKeys.settingsVersion.tr),
        content: Text(AppVersion.fullLabel),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(StringKeys.settingsDone.tr),
          ),
        ],
      ),
    );
  }

  void _syncCaptionSizeToHome(double size) {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().updateDefaultCaptionFontSize(size);
    }
  }

  void _syncSaveTranscriptsToHome(bool enabled) {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().updateSaveTranscriptsEnabled(enabled);
    }
  }
}
