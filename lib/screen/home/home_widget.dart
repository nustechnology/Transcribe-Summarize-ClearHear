import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../lang/string_keys.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_titlebar.dart';
import 'components/audio_visualizer.dart';
import 'components/option_row.dart';
import 'components/privacy_note.dart';
import 'components/primary_action_button.dart';
import 'components/save_session_sheet.dart';
import 'components/status_bar.dart';
import 'components/transcript_card.dart';
import 'controllers/home_controller.dart';
import '../../style/theme.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeController controller = Get.find<HomeController>();
  Worker? _savePromptWorker;
  Worker? _micPermissionWorker;

  @override
  void initState() {
    super.initState();
    _savePromptWorker = ever<bool>(controller.showSaveSessionPrompt, (show) {
      if (!show) return;
      if (!controller.tryBeginSaveSheetPresentation()) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.showSaveSessionPrompt.value) {
          controller.endSaveSheetPresentation();
          return;
        }
        unawaited(_openSaveSessionSheet());
      });
    });

    _micPermissionWorker =
        ever<bool>(controller.showMicPermissionPrompt, (show) {
      if (!show) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.showMicPermissionPrompt.value) return;
        unawaited(_openMicPermissionDialog());
      });
    });
  }

  @override
  void dispose() {
    _savePromptWorker?.dispose();
    _micPermissionWorker?.dispose();
    super.dispose();
  }

  Future<void> _openMicPermissionDialog() async {
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => AppDialog(
          icon: Icons.mic_off_outlined,
          title: StringKeys.microphonePermissionDenied.tr,
          message: StringKeys.microphonePermissionMessage.tr,
          secondaryLabel: StringKeys.microphonePermissionCancel.tr,
          onSecondary: () => Navigator.of(dialogContext).pop(),
          primaryLabel: StringKeys.microphonePermissionOpenSettings.tr,
          onPrimary: () {
            Navigator.of(dialogContext).pop();
            unawaited(controller.openMicrophoneSettings());
          },
        ),
      );
    } finally {
      controller.dismissMicPermissionPrompt();
    }
  }

  Future<void> _openSaveSessionSheet() async {
    if (!mounted) {
      controller.endSaveSheetPresentation();
      return;
    }

    var savedSession = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SaveSessionSheet(
          controller: controller,
          initialTitle: controller.defaultSessionTitle,
          onDiscard: () {
            controller.discardPendingSession();
            Navigator.of(sheetContext).pop();
          },
          onSave: (title) async {
            savedSession = await controller.savePendingSession(title);
            if (savedSession && sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        ),
      );

      if (savedSession) {
        await controller.navigateToHistoryAfterSave();
      }
    } finally {
      controller.endSaveSheetPresentation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isListening = controller.isCaptioning.value;
      final isPaused = controller.isPaused.value;

      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const AppTitleBar(),
                      const SizedBox(height: 8),
                      const StatusBar(),
                      const SizedBox(height: 16),
                      const Expanded(child: TranscriptCard()),
                      const SizedBox(height: 12),
                      if (isListening) ...[
                        if (isPaused) ...[
                          const OptionsRow(),
                          const SizedBox(height: 10),
                        ],
                        const AudioVisualizer(),
                        const SizedBox(height: 10),
                        const PrimaryActionButton(),
                        const SizedBox(height: 8),
                        if (!isPaused) ...[
                          const OptionsRow(),
                        ],
                        if (isPaused) ...[
                          const PrivacyNote(),
                        ],
                      ] else ...[
                        const OptionsRow(),
                        const SizedBox(height: 10),
                        const AudioVisualizer(),
                        const SizedBox(height: 10),
                        const PrimaryActionButton(),
                        const SizedBox(height: 8),
                        const PrivacyNote(),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
