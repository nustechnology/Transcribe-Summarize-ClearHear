import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../style/theme.dart';
import '../controllers/home_controller.dart';

class StatusBar extends GetView<HomeController> {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.isCaptioning.value;

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
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.statusActive : AppColors.statusIdle,
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
                    color: isActive ? AppColors.primary : AppColors.textMuted,
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
                        color: AppColors.statusActive.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.statusActive,
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
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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
            color: AppColors.border,
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
