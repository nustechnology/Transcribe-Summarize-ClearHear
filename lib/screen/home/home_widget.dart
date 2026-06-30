import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../lang/string_keys.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const double _transcriptFontSize = 26;

  bool _isCaptioning = false;

  void _toggleCaptioning() {
    setState(() => _isCaptioning = !_isCaptioning);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const _HomeHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: _TranscriptCard(
                  isCaptioning: _isCaptioning,
                  transcriptFontSize: _transcriptFontSize,
                ),
              ),
              const SizedBox(height: 24),
              _HomeFooter(
                isCaptioning: _isCaptioning,
                onToggleCaptioning: _toggleCaptioning,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFB0B0B0),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              StringKeys.homeStatusIdle.tr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9E9E9E),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _FontSizeButton(label: 'A–', onPressed: () {}),
            const SizedBox(width: 8),
            _FontSizeButton(label: 'A+', onPressed: () {}),
          ],
        ),
      ],
    );
  }
}

class _FontSizeButton extends StatelessWidget {
  const _FontSizeButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color(0xFFD1D1D1)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF616161),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({
    required this.isCaptioning,
    required this.transcriptFontSize,
  });

  final bool isCaptioning;
  final double transcriptFontSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _DottedBorderPainter(
        color: Color(0xFFD1D1D1),
        dotRadius: 1.5,
        dotSpacing: 5,
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: isCaptioning
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    StringKeys.homeSpeakerLabel.tr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB0B0B0),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    StringKeys.homePlaceholderTranscript.tr,
                    style: TextStyle(
                      fontSize: transcriptFontSize,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF757575),
                      height: 1.4,
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topCenter,
                child: Text(
                  StringKeys.homeIdlePrompt.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF9E9E9E),
                    height: 1.4,
                  ),
                ),
              ),
      ),
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter({
    required this.isCaptioning,
    required this.onToggleCaptioning,
  });

  final bool isCaptioning;
  final VoidCallback onToggleCaptioning;

  static const _borderColor = Color(0xFF1A1A1A);
  static const _buttonBorderRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    if (isCaptioning) {
      return Row(
        children: [
          Expanded(
            child: _OutlinedActionButton(
              onPressed: onToggleCaptioning,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _borderColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  StringKeys.homeStop.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _borderColor,
                  ),
                ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _OutlinedIconButton(
            onPressed: () {},
            child: const _PlayIcon(),
          ),
          const SizedBox(width: 12),
          const _IndicatorDots(),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Material(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(_buttonBorderRadius),
            child: InkWell(
              onTap: onToggleCaptioning,
              borderRadius: BorderRadius.circular(_buttonBorderRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    StringKeys.homeStartCaptioning.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const _IndicatorDots(),
      ],
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_HomeFooter._buttonBorderRadius),
        side: const BorderSide(color: _HomeFooter._borderColor),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_HomeFooter._buttonBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: child,
        ),
      ),
    );
  }
}

class _OutlinedIconButton extends StatelessWidget {
  const _OutlinedIconButton({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_HomeFooter._buttonBorderRadius),
        side: const BorderSide(color: _HomeFooter._borderColor),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_HomeFooter._buttonBorderRadius),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _PlayIcon extends StatelessWidget {
  const _PlayIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(14, 16),
      painter: _TrianglePainter(color: _HomeFooter._borderColor),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class _IndicatorDots extends StatelessWidget {
  const _IndicatorDots();

  static const _dotColor = Color(0xFFBDBDBD);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        6,
        (index) => Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 5),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  const _DottedBorderPainter({
    required this.color,
    required this.dotRadius,
    required this.dotSpacing,
    required this.radius,
  });

  final Color color;
  final double dotRadius;
  final double dotSpacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final inset = dotRadius;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final step = dotRadius * 2 + dotSpacing;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, dotRadius, paint);
        }
        distance += step;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        dotRadius != oldDelegate.dotRadius ||
        dotSpacing != oldDelegate.dotSpacing ||
        radius != oldDelegate.radius;
  }
}
