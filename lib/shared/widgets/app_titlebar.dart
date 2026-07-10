import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/route/app_route.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class AppTitleBar extends StatelessWidget {
  final bool showActionIcon;
  final Widget? actionIcon;
  final VoidCallback? onActionPressed;

  const AppTitleBar({
    super.key,
    this.showActionIcon = true,
    this.actionIcon,
    this.onActionPressed,
  });

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
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        if (showActionIcon)
          IconButton(
            onPressed: onActionPressed ?? _openSettings,
            icon: actionIcon ??
                const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
      ],
    );
  }

  void _openSettings() {
    Get.rootDelegate.offNamed(AppRoutes.settings);
  }
}
