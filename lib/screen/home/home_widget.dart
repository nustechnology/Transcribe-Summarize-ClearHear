import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../lang/string_keys.dart';
import '../../screen/history/history_widget.dart';
import 'controllers/home_controller.dart';

abstract final class _AppColors {
  static const background = Color(0xFFF0EFEC);
  static const primary = Color(0xFF1C5B5B);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textMuted = Color(0xFF9E9E9E);
  static const border = Color(0xFFE0E0E0);
  static const confidenceBlue = Color(0xFF1976D2);
  static const privacyBg = Color(0xFFE3F2FD);
  static const statusIdle = Color(0xFFB0B0B0);
  static const statusActive = Color(0xFF4CAF50);
  static const stopRed = Color(0xFFE66754);
}

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isListening = controller.isCaptioning.value;
      final selectedIndex = controller.selectedNavIndex.value;

      return Scaffold(
        backgroundColor: _AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: selectedIndex == 1
                    ? const HistoryView()
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            const _AppTitleBar(),
                            const SizedBox(height: 8),
                            const _StatusBar(),
                            const SizedBox(height: 16),
                            const Expanded(child: _TranscriptCard()),
                            const SizedBox(height: 12),
                            if (isListening) ...[
                              const _AudioVisualizer(),
                              const SizedBox(height: 16),
                              const _PrimaryActionButton(),
                              const SizedBox(height: 12),
                              const _OptionsRow(),
                            ] else ...[
                              const _OptionsRow(),
                              const SizedBox(height: 16),
                              const _AudioVisualizer(),
                              const SizedBox(height: 16),
                              const _PrimaryActionButton(),
                              const SizedBox(height: 12),
                              const _PrivacyNote(),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
              ),
              const _BottomNavBar(),
            ],
          ),
        ),
      );
    });
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
          color: _AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.border.withOpacity(0.6)),
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
                      ? StringKeys.homeStatusListening.tr
                      : StringKeys.homeStatusIdle.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? _AppColors.primary : _AppColors.textMuted,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _AppColors.statusActive.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _AppColors.statusActive,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isCaptioning ? _AppColors.surface : _AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: isCaptioning ? Border.all(color: _AppColors.border.withOpacity(0.5)) : null,
          boxShadow: isCaptioning
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _AppColors.background.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.message_outlined,
              size: 32,
              color: _AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            StringKeys.homeIdlePromptLine1.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          Text(
            StringKeys.homeIdlePromptLine2.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsRow extends GetView<HomeController> {
  const _OptionsRow();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isListening = controller.isCaptioning.value;

      if (isListening) {
        return const Row(
          children: [
            Expanded(
              child: _OptionChip(
                icon: Icons.verified_user_outlined,
                iconColor: _AppColors.primary,
                labelKey: StringKeys.homeConfidenceLabel,
                trailingKey: StringKeys.homeConfidenceHigh,
                trailingColor: _AppColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _OptionChip(
                icon: Icons.language,
                iconColor: _AppColors.primary,
                labelKey: StringKeys.homeLanguageEnglish,
                showChevron: true,
              ),
            ),
          ],
        );
      }

      return const Row(
        children: [
          Expanded(
            child: _OptionChip(
              icon: Icons.language,
              iconColor: _AppColors.primary,
              labelKey: StringKeys.homeLanguageEnglish,
              showChevron: true,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _OptionChip(
              icon: Icons.verified_user_outlined,
              iconColor: _AppColors.primary,
              labelKey: StringKeys.homeConfidenceLabel,
              trailingKey: StringKeys.homeConfidenceMedium,
            ),
          ),
        ],
      );
    });
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.icon,
    required this.labelKey,
    this.trailingKey,
    this.showChevron = false,
    this.iconColor,
    this.trailingColor,
  });

  final IconData icon;
  final String labelKey;
  final String? trailingKey;
  final bool showChevron;
  final Color? iconColor;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? _AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              labelKey.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingKey != null)
            Text(
              trailingKey!.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trailingColor ?? _AppColors.confidenceBlue,
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

  static const _barCount = 32;
  static const _listeningBarWidth = 2.5;
  static const _listeningBarGap = 3.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.isCaptioning.value;

      if (!isActive) {
        return Row(
          children: [
            const Icon(
              Icons.mic_none,
              size: 20,
              color: _AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: List.generate(_barCount, (_) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0D0D0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      }

      return SizedBox(
        height: 36,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barCount = math.max(
              40,
              ((constraints.maxWidth + _listeningBarGap) /
                      (_listeningBarWidth + _listeningBarGap))
                  .floor(),
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(barCount, (index) {
                final progress = index / barCount;
                final wave = (math.sin(index * 0.55) * 0.4 +
                        math.sin(index * 0.23 + 1) * 0.35 +
                        math.sin(index * 0.91 + 2) * 0.25)
                    .abs();
                final height = 6.0 + wave * 26.0;
                final opacity = (1.0 - progress * 0.9).clamp(0.08, 1.0);

                return Padding(
                  padding: EdgeInsets.only(
                    right: index < barCount - 1 ? _listeningBarGap : 0,
                  ),
                  child: Container(
                    width: _listeningBarWidth,
                    height: height,
                    decoration: BoxDecoration(
                      color: _AppColors.primary.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(_listeningBarWidth),
                    ),
                  ),
                );
              }),
            );
          },
        ),
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

      if (isCaptioning) {
        return Row(
          children: [
            Expanded(
              child: _ActionButton(
                labelKey: StringKeys.homeStopCaptioning,
                icon: Icons.stop_rounded,
                filled: true,
                backgroundColor: _AppColors.stopRed,
                foregroundColor: Colors.white,
                onPressed: isProcessing ? null : controller.stopCaptioning,
              ),
            ),
            const SizedBox(width: 12),
            _PauseButton(onPressed: () {}),
          ],
        );
      }

      final isWhisperLoading = controller.isWhisperModelLoading.value;
      final isStartDisabled =
          isProcessing || isWhisperLoading || !controller.isWhisperModelReady.value;

      return Opacity(
        opacity: isWhisperLoading ? 0.45 : 1.0,
        child: _ActionButton(
          labelKey: StringKeys.homeStartCaptioning,
          icon: Icons.mic,
          filled: true,
          onPressed: isStartDisabled ? null : controller.startCaptioning,
        ),
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
    this.backgroundColor,
    this.foregroundColor,
  });

  final String labelKey;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? (filled ? _AppColors.primary : _AppColors.surface);
    final fgColor = foregroundColor ?? (filled ? Colors.white : _AppColors.primary);

    return Material(
      color: bgColor,
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
              Icon(icon, size: 20, color: fgColor),
              const SizedBox(width: 10),
              Text(
                labelKey.tr,
                style: TextStyle(
                  color: fgColor,
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

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 56,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _AppColors.border),
          ),
          child: const Icon(
            Icons.pause_rounded,
            size: 24,
            color: _AppColors.textPrimary,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 18),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                StringKeys.homePrivacyOnDevice.tr,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _AppColors.confidenceBlue,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                StringKeys.homePrivacyNotStored.tr,
                style: const TextStyle(
                  fontSize: 8,
                  color: _AppColors.textSecondary,
                  height: 1,
                ),
              ),
            ],
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
                  icon: Icons.graphic_eq,
                  selectedIcon: Icons.graphic_eq,
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
                  icon: Icons.description_outlined,
                  selectedIcon: Icons.description,
                  labelKey: StringKeys.navSummary,
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
