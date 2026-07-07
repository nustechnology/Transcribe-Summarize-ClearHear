import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';

import '../../../style/theme.dart';

class AudioVisualizer extends GetView<HomeController> {
  const AudioVisualizer({super.key});

  static const _barCount = 32;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.isCaptioning.value;
      final isPaused = controller.isPaused.value;

      if (!isActive) {
        return const _IdleVisualizer();
      }

      if (isPaused) {
        return _PausedWaveformFrame(
          waveData: controller.recorderController.waveData,
        );
      }

      return SizedBox(
        height: 36,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _LiveWaveform(
              recorder: controller.recorderController,
              size: Size(constraints.maxWidth, 36),
            );
          },
        ),
      );
    });
  }

}

abstract final class _WaveformMetrics {
  static const barWidth = 2.5;
  static const barGap = 3.0;
  static const barColor = AppColors.primary;
  static const minBarHeight = 8.0;
  static const maxBarHeight = 32.0;
  static const barInterval = Duration(milliseconds: 180);
  static const scrollDuration = Duration(milliseconds: 200);
  static const maxStoredBars = 120;

  static double get barStep => barWidth + barGap;

  static double rmsFromPcmChunk(Uint8List bytes) {
    if (bytes.isEmpty) return 0;

    if (Platform.isIOS) {
      if (bytes.length < 4) return 0;

      final sampleCount = bytes.length ~/ 4;
      final samples = bytes.buffer.asFloat32List(
        bytes.offsetInBytes,
        sampleCount,
      );
      var sum = 0.0;
      for (final sample in samples) {
        sum += sample * sample;
      }
      return math.sqrt(sum / samples.length);
    }

    var sum = 0.0;
    var count = 0;
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final sample = view.getInt16(i, Endian.little);
      sum += sample * sample;
      count++;
    }
    if (count == 0) return 0;

    return math.sqrt(sum / count) / 32768.0;
  }

  static double heightFromRms(double rms) {
    if (rms < 0.006) return minBarHeight;

    final db = 20 * math.log(rms + 1e-9) / math.ln10;
    const minDb = -48.0;
    const maxDb = -14.0;
    final normalized = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    final curved = math.pow(normalized, 0.7).toDouble();

    return minBarHeight + curved * (maxBarHeight - minBarHeight);
  }
}

mixin _WaveformScrollBehavior<T extends StatefulWidget> on State<T> {
  ScrollController get waveformScrollController;

  void scrollWaveformToEnd() {
    if (!waveformScrollController.hasClients) return;

    final target = waveformScrollController.position.maxScrollExtent;
    if ((target - waveformScrollController.offset).abs() < 0.5) return;

    waveformScrollController.animateTo(
      target,
      duration: _WaveformMetrics.scrollDuration,
      curve: Curves.linear,
    );
  }

  void trimWaveformBars(List<double> bars) {
    if (!waveformScrollController.hasClients ||
        bars.length <= _WaveformMetrics.maxStoredBars) {
      return;
    }

    final scrolledBars =
        (waveformScrollController.offset / _WaveformMetrics.barStep).floor();
    final removeCount = math.min(
      scrolledBars - 6,
      bars.length - _WaveformMetrics.maxStoredBars,
    );
    if (removeCount <= 0) return;

    setState(() {
      bars.removeRange(0, removeCount);
    });

    final nextOffset = (waveformScrollController.offset -
            removeCount * _WaveformMetrics.barStep)
        .clamp(0.0, double.infinity);
    waveformScrollController.jumpTo(nextOffset);
  }
}

class _WaveformScrollView extends StatelessWidget {
  const _WaveformScrollView({
    required this.heights,
    required this.size,
    required this.scrollController,
  });

  final List<double> heights;
  final Size size;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size.height,
      width: size.width,
      child: ClipRect(
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: size.width),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(heights.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < heights.length - 1 ? _WaveformMetrics.barGap : 0,
                    ),
                    child: Container(
                      width: _WaveformMetrics.barWidth,
                      height: heights[index],
                      decoration: BoxDecoration(
                        color: _WaveformMetrics.barColor,
                        borderRadius:
                            BorderRadius.circular(_WaveformMetrics.barWidth),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveWaveform extends StatefulWidget {
  const _LiveWaveform({
    required this.recorder,
    required this.size,
  });

  final RecorderController recorder;
  final Size size;

  @override
  State<_LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<_LiveWaveform>
    with _WaveformScrollBehavior {
  final ScrollController _scrollController = ScrollController();
  final List<double> _bars = [];
  Timer? _timer;
  StreamSubscription<Uint8List>? _chunkSubscription;
  double _windowPeak = 0;

  @override
  ScrollController get waveformScrollController => _scrollController;

  @override
  void initState() {
    super.initState();
    _chunkSubscription = widget.recorder.onAudioChunks.listen(_onAudioChunk);
    _timer = Timer.periodic(_WaveformMetrics.barInterval, _onInterval);
  }

  @override
  void dispose() {
    _chunkSubscription?.cancel();
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onAudioChunk(Uint8List chunk) {
    final rms = _WaveformMetrics.rmsFromPcmChunk(chunk);
    if (rms > _windowPeak) {
      _windowPeak = rms;
    }
  }

  void _onInterval(Timer _) {
    if (!mounted) return;

    final peak = _windowPeak;
    _windowPeak = 0;

    setState(() {
      _bars.add(_WaveformMetrics.heightFromRms(peak));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scrollWaveformToEnd();
      trimWaveformBars(_bars);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _WaveformScrollView(
      heights: _bars,
      size: widget.size,
      scrollController: _scrollController,
    );
  }
}

class _PausedWaveformFrame extends StatelessWidget {
  const _PausedWaveformFrame({required this.waveData});

  final List<double> waveData;

  static const _sampleCount = 28;
  static const _dotColor = Color(0xFFC8C8C8);
  static const _fallbackHeights = [
    0.18, 0.22, 0.28, 0.35, 0.52, 0.78, 0.92, 0.64, 0.38, 0.24,
    0.18, 0.2, 0.22, 0.26, 0.3, 0.22, 0.18, 0.2, 0.22, 0.18,
    0.2, 0.22, 0.24, 0.2, 0.18, 0.2, 0.22, 0.18,
  ];

  @override
  Widget build(BuildContext context) {
    final samples = _resolvedSamples();

    return Container(
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < samples.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            _PausedWaveElement(value: samples[i]),
          ],
        ],
      ),
    );
  }

  List<double> _resolvedSamples() {
    if (waveData.isEmpty) {
      return _fallbackHeights;
    }

    const targetCount = _sampleCount;
    if (waveData.length <= targetCount) {
      return List<double>.from(waveData);
    }

    final step = waveData.length / targetCount;
    return List<double>.generate(targetCount, (index) {
      final sampleIndex = (index * step).floor().clamp(0, waveData.length - 1);
      return waveData[sampleIndex];
    });
  }
}

class _PausedWaveElement extends StatelessWidget {
  const _PausedWaveElement({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    if (value < 0.12) {
      return Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: _PausedWaveformFrame._dotColor,
          shape: BoxShape.circle,
        ),
      );
    }

    final barHeight = 4.0 + value.clamp(0.0, 1.0) * 14.0;
    return Container(
      width: 3,
      height: barHeight,
      decoration: BoxDecoration(
        color: _PausedWaveformFrame._dotColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _IdleVisualizer extends StatelessWidget {
  const _IdleVisualizer();

  @override
  Widget build(BuildContext context) {
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
            children: List.generate(AudioVisualizer._barCount, (_) {
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
}
