import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../style/theme.dart';

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 18),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.privacyBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 16,
            color: AppColors.confidenceBlue,
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
                  color: AppColors.confidenceBlue,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                StringKeys.homePrivacyNotStored.tr,
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.textSecondary,
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