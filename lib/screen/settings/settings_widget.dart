import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/shared/app_version.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_titlebar.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

import 'controllers/settings_controller.dart';
import 'widgets/caption_size_stepper.dart';
import 'widgets/settings_section_card.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const AppTitleBar(
                  actionIcon: SizedBox(width: 40, height: 40),
                ),
                Text(
                  StringKeys.navSettings.tr,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.title,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                SettingsSectionCard(
                  icon: Icons.desktop_windows_outlined,
                  title: StringKeys.settingsDisplay.tr,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            StringKeys.settingsCaptionSize.tr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const CaptionSizeStepper(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      StringKeys.settingsCaptionSizeHint.tr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.shield_outlined,
                  title: StringKeys.settingsPrivacy.tr,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SettingsRowLabel(
                            title: StringKeys.settingsSaveTranscripts.tr,
                            subtitle:
                                StringKeys.settingsSaveTranscriptsHint.tr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Obx(
                          () => Switch.adaptive(
                            value: controller.saveTranscripts.value,
                            activeTrackColor: AppColors.primary,
                            activeThumbColor: Colors.white,
                            onChanged: controller.setSaveTranscripts,
                          ),
                        ),
                      ],
                    ),
                    const SettingsDivider(),
                    InkWell(
                      onTap: controller.isClearing.value
                          ? null
                          : controller.confirmAndClearAllData,
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SettingsRowLabel(
                              title: StringKeys.settingsClearAllData.tr,
                              subtitle:
                                  StringKeys.settingsClearAllDataHint.tr,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                StringKeys.settingsErase.tr,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: controller.isClearing.value
                                      ? AppColors.textMuted
                                      : AppColors.stopRed,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 22,
                                color: controller.isClearing.value
                                    ? AppColors.textMuted
                                    : AppColors.stopRed,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsSectionCard(
                  icon: Icons.info_outline,
                  title: StringKeys.settingsAbout.tr,
                  children: [
                    Text(
                      StringKeys.settingsAboutDescription.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.body,
                        height: 1.45,
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsNavRow(
                      leading: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(
                          Icons.help_outline,
                          size: 24,
                          color: AppColors.primary,
                        ),
                      ),
                      title: StringKeys.settingsHelpSupport.tr,
                      onTap: controller.openHelpAndSupport,
                    ),
                    const SettingsDivider(),
                    SettingsNavRow(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppVersion.version,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cardBackground,
                          ),
                        ),
                      ),
                      title: StringKeys.settingsVersion.tr,
                      subtitle: AppVersion.fullLabel,
                      onTap: controller.openVersionInfo,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }),
      ),
    );
  }
}
