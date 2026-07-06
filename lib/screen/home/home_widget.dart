import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../style/theme.dart';

import 'components/app_title_bar.dart';
import 'components/status_bar.dart';
import 'components/transcript_card.dart';
import 'components/audio_visualizer.dart';
import 'components/primary_action_button.dart';
import 'components/option_row.dart';
import 'components/privacy_note.dart';
import 'controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isListening = controller.isCaptioning.value;

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
                        const AudioVisualizer(),
                        const SizedBox(height: 16),
                        const PrimaryActionButton(),
                        const SizedBox(height: 12),
                        const OptionsRow(),
                      ] else ...[
                        const OptionsRow(),
                        const SizedBox(height: 16),
                        const AudioVisualizer(),
                        const SizedBox(height: 16),
                        const PrimaryActionButton(),
                        const SizedBox(height: 12),
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
