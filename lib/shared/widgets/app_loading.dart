import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:transcribe_summarize_clearhear/style/app_colors.dart';

/// Loading animation: 4 dots arranged in a circle, rotating.
class AppLoading extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double radius;

  const AppLoading({
    super.key,
    this.color,
    this.dotSize = 14,
    this.radius = 16,
  });

  @override
  State<AppLoading> createState() => _FourDotsLoadingState();
}

class _FourDotsLoadingState extends State<AppLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _colorTimer;
  final _random = math.Random();

  static const _opacities = [1.0, 0.75, 0.5, 0.3];
  late List<double> _dotOpacities;

  void _shuffleOpacities() {
    if (!mounted) return;
    setState(() {
      _dotOpacities = List.of(_opacities)..shuffle(_random);
    });
  }

  @override
  void initState() {
    super.initState();
    _dotOpacities = List.of(_opacities)..shuffle(_random);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _colorTimer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) => _shuffleOpacities(),
    );
  }

  @override
  void dispose() {
    _colorTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final dotSize = widget.dotSize;
    final radius = widget.radius;
    final side = radius * 2 + dotSize * 2;

    return UnconstrainedBox(
      child: SizedBox(
        width: side,
        height: side,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(4, (i) {
                  final angle = i * math.pi / 2;
                  final x = radius * math.cos(angle);
                  final y = radius * math.sin(angle);
                  return Transform.translate(
                    offset: Offset(x, y),
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(_dotOpacities[i]),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}
