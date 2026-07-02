import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/style/app_colors.dart';

class AppTitleBar extends StatelessWidget {
  final Widget? actionIcon;
  final VoidCallback? onActionPressed;

  const AppTitleBar({
    super.key,
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
        IconButton(
          onPressed: onActionPressed,
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
}