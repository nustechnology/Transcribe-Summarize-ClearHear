import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';

import '../../../style/theme.dart';

class AudioVisualizer extends GetView<HomeController> {
  const AudioVisualizer({super.key});

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
              color: AppColors.textMuted,
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
                      color: AppColors.primary.withValues(alpha: opacity),
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
