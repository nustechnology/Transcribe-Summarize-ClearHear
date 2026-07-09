import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../style/theme.dart';
import '../controllers/settings_controller.dart';

class CaptionSizeStepper extends GetView<SettingsController> {
  const CaptionSizeStepper({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final size = controller.captionSize.value.round();
      final canDecrease =
          controller.captionSize.value > SettingsController.minCaptionSize;
      final canIncrease =
          controller.captionSize.value < SettingsController.maxCaptionSize;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            enabled: canDecrease,
            onPressed: controller.decreaseCaptionSize,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              StringKeys.settingsCaptionSizeValue.trParams({'size': '$size'}),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            enabled: canIncrease,
            onPressed: controller.increaseCaptionSize,
          ),
        ],
      );
    });
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chipBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
