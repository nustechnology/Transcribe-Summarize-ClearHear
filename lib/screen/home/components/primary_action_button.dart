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

      if (isCaptioning) {
        return Row(
          children: [
            Expanded(
              child: _ActionButton(
                labelKey: StringKeys.homeStopCaptioning,
                icon: Icons.stop_rounded,
                filled: true,
                backgroundColor: AppColors.stopRed,
                foregroundColor: Colors.white,
                onPressed: isProcessing ? null : controller.stopCaptioning,
              ),
            ),
            const SizedBox(width: 12),
            _PauseButton(onPressed: () => isProcessing ? null : controller.pauseCaptioning),
          ],
        );
      }

      final isAsrLoading = controller.isAsrModelLoading.value;
      final isStartDisabled =
          isProcessing || isAsrLoading || !controller.isAsrModelReady.value;

      return Opacity(
        opacity: isAsrLoading ? 0.45 : 1.0,
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
    final bgColor = backgroundColor ?? (filled ? AppColors.primary : AppColors.surface);
    final fgColor = foregroundColor ?? (filled ? Colors.white : AppColors.primary);

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
            border: filled ? null : Border.all(color: AppColors.primary),
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 56,
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
