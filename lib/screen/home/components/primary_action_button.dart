import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../style/theme.dart';
import '../controllers/home_controller.dart';

class PrimaryActionButton extends GetView<HomeController> {
  const PrimaryActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCaptioning = controller.isCaptioning.value;
      final isProcessing = controller.isProcessing.value;
      final isPaused = controller.isPaused.value;
      final isPausing = controller.isPausing.value;
      final isFinishingTranscript = controller.isFinishingTranscript.value;

      if (isFinishingTranscript) {
        return const Opacity(
          opacity: 0.45,
          child: _ActionButton(
            labelKey: StringKeys.homeStopCaptioning,
            icon: Icons.stop_rounded,
            filled: true,
            backgroundColor: AppColors.stopRed,
            foregroundColor: Colors.white,
            isLoading: true,
            onPressed: null,
          ),
        );
      }

      if (isCaptioning) {
        if (isPaused) {
          return Row(
            children: [
              Expanded(
                child: _ActionButton(
                  labelKey: StringKeys.homeResumeCaptioning,
                  icon: Icons.play_arrow_rounded,
                  filled: true,
                  compact: true,
                  onPressed: isProcessing || isPausing ? null : controller.resumeCaptioning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  labelKey: StringKeys.homeStopCaptioning,
                  icon: Icons.stop_rounded,
                  filled: false,
                  compact: true,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.stopRed,
                  borderColor: AppColors.stopRed,
                  onPressed: isProcessing || isPausing
                      ? null
                      : controller.stopCaptioning,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _ActionButton(
                labelKey: StringKeys.homeStopCaptioning,
                icon: Icons.stop_rounded,
                filled: true,
                backgroundColor: AppColors.stopRed,
                foregroundColor: Colors.white,
                onPressed: isProcessing || isPausing
                    ? null
                    : controller.stopCaptioning,
              ),
            ),
            const SizedBox(width: 12),
            _PauseButton(
              onPressed:
                  isProcessing || isPausing ? null : controller.pauseCaptioning,
            ),
          ],
        );
      }

      final isAsrLoading = controller.isAsrModelLoading.value;
      final isStartDisabled =
          isProcessing || isAsrLoading || !controller.isAsrModelReady.value;
      final downloadPct = (controller.asrModelDownloadProgress.value * 100)
          .clamp(0, 100)
          .round();
      final isDownloading = downloadPct > 0 && downloadPct < 100;
      final loadingLabel = isDownloading
          ? '${StringKeys.homeLoadingModel.tr} $downloadPct%'
          : StringKeys.homeLoadingModel.tr;

      return Opacity(
        opacity: isAsrLoading ? 0.45 : 1.0,
        child: _ActionButton(
          labelKey: StringKeys.homeStartCaptioning,
          labelText: isAsrLoading ? loadingLabel : null,
          icon: isAsrLoading ? Icons.download_rounded : Icons.mic,
          filled: true,
          loadingDots: isAsrLoading && !isDownloading,
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
    this.labelText,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.compact = false,
    this.loadingDots = false,
    this.isLoading = false,
  });

  final String labelKey;
  final String? labelText;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final bool compact;
  final bool loadingDots;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? (filled ? AppColors.primary : AppColors.surface);
    final fgColor = foregroundColor ?? (filled ? Colors.white : AppColors.primary);
    final borderRadius = BorderRadius.circular(compact ? 12 : 14);
    final verticalPadding = compact ? 10.0 : 16.0;
    final iconSize = compact ? 22.0 : 24.0;
    final fontSize = compact ? 14.0 : 16.0;
    final iconGap = compact ? 6.0 : 10.0;
    final resolvedBorderColor =
        borderColor ?? (filled ? null : AppColors.primary);

    return Material(
      color: bgColor,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: resolvedBorderColor == null
                ? null
                : Border.all(color: resolvedBorderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fgColor,
                  ),
                )
              else
                Icon(icon, size: iconSize, color: fgColor),
              SizedBox(width: iconGap),
              Text(
                labelText ?? labelKey.tr,
                style: TextStyle(
                  color: fgColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (loadingDots)
                _AnimatedEllipsis(
                  style: TextStyle(
                    color: fgColor,
                    fontSize: fontSize,
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

class _AnimatedEllipsis extends StatefulWidget {
  const _AnimatedEllipsis({required this.style});

  final TextStyle style;

  @override
  State<_AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<_AnimatedEllipsis>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dotCount = (_controller.value * 3).floor() % 3 + 1;
        return SizedBox(
          width: 18,
          child: Text('.' * dotCount, style: widget.style),
        );
      },
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 100,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.pause_rounded,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
