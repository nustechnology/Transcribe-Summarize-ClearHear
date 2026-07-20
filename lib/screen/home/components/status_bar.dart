import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/screen/home/controllers/home_controller.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';
import 'package:transcribe_summarize_clearhear/shared/caption_size_config.dart';

class StatusBar extends GetView<HomeController> {
  const StatusBar({super.key});

  String _getStatusText(HomeController controller) {
    if (controller.isCaptioning.value) {
      return controller.isPaused.value
          ? StringKeys.homeStatusPaused.tr
          : StringKeys.homeStatusListening.tr;
    }
    return StringKeys.homeStatusIdle.tr;
  }

  Color _getStatusColor(HomeController controller) {
    if (controller.isCaptioning.value) {
      return controller.isPaused.value
          ? AppColors.stopRed
          : AppColors.statusActive;
    }
    return AppColors.statusIdle;
  }

  Color _getStatusTextColor(HomeController controller) {
    return controller.isCaptioning.value
        ? AppColors.primary
        : AppColors.statusIdle;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.isCaptioning.value;
      final isPaused = controller.isPaused.value;

      if (isActive && isPaused) {
        return _buildPausedBar();
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(controller),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(controller),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getStatusTextColor(controller),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  const _ListeningPulse(),
                ],
              ],
            ),
            _FontSizeControl(
              onDecrease: controller.decreaseFontSize,
              onIncrease: controller.increaseFontSize,
              canDecrease:
                  controller.transcriptFontSize.value > CaptionSizeConfig.min,
              canIncrease:
                  controller.transcriptFontSize.value < CaptionSizeConfig.max,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPausedBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.stopRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StringKeys.homeStatusPaused.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.stopRed,
                  ),
                ),
                Text(
                  StringKeys.homeStopCaptioningPaused.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const _PausedWaveform(),
        ],
      ),
    );
  }
}

class _ListeningPulse extends StatefulWidget {
  const _ListeningPulse();

  @override
  State<_ListeningPulse> createState() => _ListeningPulseState();
}

class _ListeningPulseState extends State<_ListeningPulse>
    with SingleTickerProviderStateMixin {
  static const _dotSize = 8.0;
  static const _ringCount = 3;
  static const _ringGap = 3.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  double _ringDiameter(int index) => _dotSize + 2 * _ringGap * (index + 1);

  double _scaleForRing(int index) {
    final t = (_controller.value + index / _ringCount) % 1.0;
    final wave = t <= 0.5 ? t * 2 : (1 - t) * 2;
    final curved = Curves.easeInOut.transform(wave);
    return 0.9 + curved * 0.14;
  }

  double _opacityForRing(int index) {
    final t = (_controller.value + index / _ringCount) % 1.0;
    final wave = t <= 0.5 ? t * 2 : (1 - t) * 2;
    final peak = 0.52 - index * 0.12;
    final floor = peak - 0.22;
    return floor + wave * (peak - floor);
  }

  double _borderWidthForRing(int index) => 2.0 - index * 0.25;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxDiameter = _ringDiameter(_ringCount - 1) * 1.04;

    return SizedBox(
      width: maxDiameter,
      height: maxDiameter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var index = _ringCount - 1; index >= 0; index--)
                Transform.scale(
                  scale: _scaleForRing(index),
                  child: Container(
                    width: _ringDiameter(index),
                    height: _ringDiameter(index),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.statusActive
                            .withValues(alpha: _opacityForRing(index)),
                        width: _borderWidthForRing(index),
                      ),
                    ),
                  ),
                ),
              child!,
            ],
          );
        },
        child: Container(
          width: _dotSize,
          height: _dotSize,
          decoration: const BoxDecoration(
            color: AppColors.statusActive,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PausedWaveform extends StatelessWidget {
  const _PausedWaveform();

  static const _barHeights = [
    0.35,
    0.55,
    0.75,
    0.45,
    0.65,
    0.85,
    0.5,
    0.4,
    0.6,
    0.7,
    0.45,
    0.55,
    0.65,
    0.85,
    0.5,
    0.4,
    0.6,
    0.7,
    0.45,
    0.55,
  ];

  @override
  Widget build(BuildContext context) {
    const maxHeight = 22.0;

    return SizedBox(
      height: maxHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barHeights.length, (index) {
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 2.5),
            child: Container(
              width: 2.5,
              height: maxHeight * _barHeights[index],
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  const _FontSizeControl({
    required this.onDecrease,
    required this.onIncrease,
    required this.canDecrease,
    required this.canIncrease,
  });

  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool canDecrease;
  final bool canIncrease;

  static TextStyle _labelStyle(bool enabled) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canDecrease || canIncrease
              ? AppColors.border
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            labelKey: StringKeys.homeFontDecrease,
            enabled: canDecrease,
            onPressed: onDecrease,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: canDecrease || canIncrease
                ? AppColors.border
                : AppColors.border.withValues(alpha: 0.5),
          ),
          _segment(
            labelKey: StringKeys.homeFontIncrease,
            enabled: canIncrease,
            onPressed: onIncrease,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String labelKey,
    required bool enabled,
    required VoidCallback onPressed,
    required BorderRadius borderRadius,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              labelKey.tr,
              style: _labelStyle(enabled),
            ),
          ),
        ),
      ),
    );
  }
}
