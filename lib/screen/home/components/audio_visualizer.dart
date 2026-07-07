import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';

import '../../../style/theme.dart';

// Shared bar geometry used by both AudioVisualizer and MiniAudioVisualizer.
const _barWidth = 2.5;
const _barGap = 3.0;

class AudioVisualizer extends GetView<HomeController> {
  const AudioVisualizer({super.key});

  static const _barCount = 32;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.isCaptioning.value;
      final isPaused = controller.isPaused.value;

      if (!isActive || isPaused) {
        return Row(
          children: [
            const Icon(
              Icons.mic,
              size: 24,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
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
              ((constraints.maxWidth + _barGap) /
                      (_barWidth + _barGap))
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
                    right: index < barCount - 1 ? _barGap : 0,
                  ),
                  child: Container(
                    width: _barWidth,
                    height: height,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(_barWidth),
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

/// Static mini waveform for the status bar (fixed 80×20, no animation).
class MiniAudioVisualizer extends StatelessWidget {
  const MiniAudioVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barCount = ((constraints.maxWidth + _barGap) /
                  (_barWidth + _barGap))
              .floor();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final wave = (math.sin(i * 0.55) * 0.4 +
                      math.sin(i * 0.23 + 1) * 0.35 +
                      math.sin(i * 0.91 + 2) * 0.25)
                  .abs();
              final height = 4.0 + wave * 12.0;
              return Padding(
                padding: EdgeInsets.only(
                  right: i < barCount - 1 ? _barGap : 0,
                ),
                child: Container(
                  width: _barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(_barWidth),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
