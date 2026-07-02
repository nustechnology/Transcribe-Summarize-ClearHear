import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../style/theme.dart';
import '../controllers/home_controller.dart';

class OptionsRow extends GetView<HomeController> {
  const OptionsRow({super.key});

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
                iconColor: AppColors.primary,
                labelKey: StringKeys.homeConfidenceLabel,
                trailingKey: StringKeys.homeConfidenceHigh,
                trailingColor: AppColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _OptionChip(
                icon: Icons.language,
                iconColor: AppColors.primary,
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
              iconColor: AppColors.primary,
              labelKey: StringKeys.homeLanguageEnglish,
              showChevron: true,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _OptionChip(
              icon: Icons.verified_user_outlined,
              iconColor: AppColors.primary,
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
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              labelKey.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
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
                color: trailingColor ?? AppColors.confidenceBlue,
              ),
            ),
          if (showChevron)
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );
  }
}
