import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../lang/string_keys.dart';
import 'controllers/home_controller.dart';

abstract final class _AppColors {
  static const background = Color(0xFFF0EFEC);
  static const primary = Color(0xFF1C5B5B);
  static const cardBackground = Color(0xFFE8E8E8);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textMuted = Color(0xFF9E9E9E);
  static const border = Color(0xFFE0E0E0);
  static const confidenceBlue = Color(0xFF1976D2);
  static const privacyBg = Color(0xFFE3F2FD);
  static const statusIdle = Color(0xFFB0B0B0);
  static const statusActive = Color(0xFF4CAF50);
}

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(height: 12),
                    _AppTitleBar(),
                    SizedBox(height: 8),
                    _StatusBar(),
                    SizedBox(height: 16),
                    Expanded(child: _TranscriptCard()),
                    SizedBox(height: 12),
                    _OptionsRow(),
                    SizedBox(height: 16),
                    _AudioVisualizer(),
                    SizedBox(height: 16),
                    _PrimaryActionButton(),
                    SizedBox(height: 12),
                    _PrivacyNote(),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _BottomNavBar(),
          ],
        ),
      ),
    );
  }
}

class _AppTitleBar extends StatelessWidget {
  const _AppTitleBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          StringKeys.appTitle.tr,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.settings_outlined,
            color: _AppColors.textPrimary,
            size: 24,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }
}

class _StatusBar extends GetView<HomeController> {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.isCaptioning.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? _AppColors.statusActive : _AppColors.statusIdle,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isActive
                      ? StringKeys.homeStatusActive.tr
                      : StringKeys.homeStatusIdle.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _AppColors.textMuted,
                  ),
                ),
              ],
            ),
            _FontSizeControl(
              onDecrease: controller.decreaseFontSize,
              onIncrease: controller.increaseFontSize,
            ),
          ],
        ),
      );
    });
  }
}

class _FontSizeControl extends StatelessWidget {
  const _FontSizeControl({
    required this.onDecrease,
    required this.onIncrease,
  });

  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  static const _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            labelKey: StringKeys.homeFontDecrease,
            onPressed: onDecrease,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(17),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: _AppColors.border,
          ),
          _segment(
            labelKey: StringKeys.homeFontIncrease,
            onPressed: onIncrease,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String labelKey,
    required VoidCallback onPressed,
    required BorderRadius borderRadius,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(labelKey.tr, style: _labelStyle),
          ),
        ),
      ),
    );
  }
}

class _TranscriptCard extends GetView<HomeController> {
  const _TranscriptCard();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCaptioning = controller.isCaptioning.value;
      final isProcessing = controller.isProcessing.value;
      final transcript = controller.transcript.value.trim();
      final summary = controller.summary.value.trim();
      final statusMessage = controller.statusMessage.value;
      final fontSize = controller.transcriptFontSize.value;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _buildContent(
          isCaptioning: isCaptioning,
          isProcessing: isProcessing,
          transcript: transcript,
          summary: summary,
          statusMessage: statusMessage,
          fontSize: fontSize,
        ),
      );
    });
  }

  Widget _buildContent({
    required bool isCaptioning,
    required bool isProcessing,
    required String transcript,
    required String summary,
    required String statusMessage,
    required double fontSize,
  }) {
    if (statusMessage.isNotEmpty) {
      return Align(
        alignment: Alignment.topCenter,
          child: Text(
            StringKeys.t(statusMessage),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFFE53935),
            height: 1.4,
          ),
        ),
      );
    }

    if (isCaptioning || transcript.isNotEmpty || summary.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              StringKeys.homeSpeakerLabel.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _AppColors.statusIdle,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            if (isProcessing)
              Text(
                StringKeys.homeProcessing.tr,
                style: TextStyle(
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                  color: _AppColors.textSecondary,
                  height: 1.4,
                ),
              )
            else if (transcript.isNotEmpty)
              Text(
                transcript,
                style: TextStyle(
                  fontSize: fontSize,
                  color: _AppColors.textPrimary,
                  height: 1.4,
                ),
              )
            else
              Text(
                StringKeys.homeListening.tr,
                style: TextStyle(
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                  color: _AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                StringKeys.homeSummaryLabel.tr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _AppColors.statusIdle,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: TextStyle(
                  fontSize: fontSize - 4,
                  color: _AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 40,
            color: _AppColors.statusIdle,
          ),
          const SizedBox(height: 16),
          Text(
            StringKeys.homeIdlePrompt.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsRow extends StatelessWidget {
  const _OptionsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _OptionChip(
            icon: Icons.language,
            labelKey: StringKeys.homeLanguageEnglish,
            showChevron: true,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _OptionChip(
            icon: Icons.verified_user_outlined,
            labelKey: StringKeys.homeConfidenceLabel,
            trailingKey: StringKeys.homeConfidenceMedium,
          ),
        ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.icon,
    required this.labelKey,
    this.trailingKey,
    this.showChevron = false,
  });

  final IconData icon;
  final String labelKey;
  final String? trailingKey;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              labelKey.tr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingKey != null)
            Text(
              trailingKey!.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _AppColors.confidenceBlue,
              ),
            ),
          if (showChevron)
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: _AppColors.textMuted,
            ),
        ],
      ),
    );
  }
}

class _AudioVisualizer extends GetView<HomeController> {
  const _AudioVisualizer();

  static const _barCount = 28;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.isCaptioning.value;

      return Row(
        children: [
          Icon(
            Icons.mic_none,
            size: 20,
            color: isActive ? _AppColors.primary : _AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: List.generate(_barCount, (index) {
                final height = isActive ? 8.0 + (index % 5) * 3.0 : 10.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        color: isActive ? _AppColors.primary.withValues(alpha: 0.4) : const Color(0xFFD0D0D0),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    });
  }
}

class _PrimaryActionButton extends GetView<HomeController> {
  const _PrimaryActionButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCaptioning = controller.isCaptioning.value;
      final isProcessing = controller.isProcessing.value;
      final hasTranscript = controller.transcript.value.trim().isNotEmpty;

      if (isCaptioning) {
        return Column(
          children: [
            _ActionButton(
              labelKey: StringKeys.homeStopCaptioning,
              icon: Icons.stop_rounded,
              filled: false,
              onPressed: isProcessing ? null : controller.toggleCaptioning,
            ),
            if (hasTranscript) ...[
              const SizedBox(height: 8),
              _ActionButton(
                labelKey: StringKeys.homeSummarize,
                icon: Icons.summarize_outlined,
                filled: true,
                onPressed: isProcessing ? null : controller.summarizeTranscript,
              ),
            ],
          ],
        );
      }

      return Column(
        children: [
          _ActionButton(
            labelKey: StringKeys.homeStartCaptioning,
            icon: Icons.mic,
            filled: true,
            onPressed: isProcessing ? null : controller.toggleCaptioning,
          ),
          if (hasTranscript) ...[
            const SizedBox(height: 8),
            _ActionButton(
              labelKey: StringKeys.homeSummarize,
              icon: Icons.summarize_outlined,
              filled: false,
              onPressed: isProcessing ? null : controller.summarizeTranscript,
            ),
          ],
        ],
      );
    });
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.labelKey,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String labelKey;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? _AppColors.primary : _AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: _AppColors.primary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: filled ? Colors.white : _AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                labelKey.tr,
                style: TextStyle(
                  color: filled ? Colors.white : _AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: _AppColors.privacyBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 16,
            color: _AppColors.confidenceBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            StringKeys.homePrivacyNote.tr,
            style: const TextStyle(
              fontSize: 13,
              color: _AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNavBar extends GetView<HomeController> {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedIndex = controller.selectedNavIndex.value;

      return Container(
        decoration: const BoxDecoration(
          color: _AppColors.surface,
          border: Border(top: BorderSide(color: _AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  labelKey: StringKeys.navLive,
                  selected: selectedIndex == 0,
                  onTap: () => controller.selectedNavIndex.value = 0,
                ),
                _NavItem(
                  icon: Icons.history,
                  selectedIcon: Icons.history,
                  labelKey: StringKeys.navHistory,
                  selected: selectedIndex == 1,
                  onTap: () => controller.selectedNavIndex.value = 1,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  labelKey: StringKeys.navSettings,
                  selected: selectedIndex == 2,
                  onTap: () => controller.selectedNavIndex.value = 2,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _AppColors.primary : _AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              labelKey.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
