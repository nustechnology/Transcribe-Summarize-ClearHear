import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../model/transcript_segment_entry.dart';
import '../../../style/theme.dart';
import '../../../util/asr_text_util.dart';
import '../controllers/home_controller.dart';

class TranscriptCard extends GetView<HomeController> {
  const TranscriptCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _TranscriptCardBody(controller: controller);
  }
}

class _TranscriptCardBody extends StatefulWidget {
  const _TranscriptCardBody({required this.controller});

  final HomeController controller;

  @override
  State<_TranscriptCardBody> createState() => _TranscriptCardBodyState();
}

class _TranscriptCardBodyState extends State<_TranscriptCardBody> {
  final ScrollController _scrollController = ScrollController();
  Worker? _transcriptWorker;
  Worker? _partialWorker;
  Worker? _summaryWorker;

  @override
  void initState() {
    super.initState();
    _transcriptWorker =
        ever(widget.controller.transcriptSegments, (_) => _scrollToBottom());
    _partialWorker =
        ever(widget.controller.partialTranscript, (_) => _scrollToBottom());
    _summaryWorker = ever(widget.controller.summary, (_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _transcriptWorker?.dispose();
    _partialWorker?.dispose();
    _summaryWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;
      if (target <= 0) return;

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Obx(() {
      final isCaptioning = controller.isCaptioning.value;
      final isPaused = controller.isPaused.value;
      final isProcessing = controller.isProcessing.value;
      final isFinishingTranscript = controller.isFinishingTranscript.value;
      final transcript = controller.transcript.value;
      final transcriptSegments = controller.transcriptSegments.toList();
      final partialTranscript = controller.partialTranscript.value;
      final summary = controller.summary.value.trim();
      final statusMessage = controller.statusMessage.value;
      final fontSize = controller.transcriptFontSize.value;
      final pausedDuration = controller.formattedCaptioningElapsed;
      final isPausing = controller.isPausing.value;
      final hasTranscript =
          transcript.trim().isNotEmpty || transcriptSegments.isNotEmpty;
      final showActiveCard =
          isCaptioning || isFinishingTranscript || hasTranscript;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: showActiveCard
              ? AppColors.surface
              : AppColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: showActiveCard
              ? Border.all(color: AppColors.border.withValues(alpha: 0.5))
              : null,
          boxShadow: showActiveCard
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: _buildContent(
          isCaptioning: isCaptioning,
          isPaused: isPaused,
          isProcessing: isProcessing,
          isFinishingTranscript: isFinishingTranscript,
          isPausing: isPausing,
          transcript: transcript,
          transcriptSegments: transcriptSegments,
          partialTranscript: partialTranscript,
          summary: summary,
          statusMessage: statusMessage,
          fontSize: fontSize,
          pausedDuration: pausedDuration,
        ),
      );
    });
  }

  Widget _statusText(String key, {double fontSize = 16}) {
    return Text(
      StringKeys.t(key),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        color: AppColors.errorRed,
        height: 1.4,
      ),
    );
  }

  Widget _buildContent({
    required bool isCaptioning,
    required bool isPaused,
    required bool isProcessing,
    required bool isFinishingTranscript,
    required bool isPausing,
    required String transcript,
    required List<TranscriptSegmentEntry> transcriptSegments,
    required String partialTranscript,
    required String summary,
    required String statusMessage,
    required double fontSize,
    required String pausedDuration,
  }) {
    final hasTranscript =
        transcript.trim().isNotEmpty || transcriptSegments.isNotEmpty;

    if (statusMessage.isNotEmpty && !hasTranscript) {
      return Align(
        alignment: Alignment.topCenter,
        child: _statusText(statusMessage),
      );
    }

    if (isCaptioning ||
        isFinishingTranscript ||
        isProcessing ||
        hasTranscript ||
        summary.isNotEmpty) {
      final transcriptBody = _buildTranscriptScrollContent(
        isCaptioning: isCaptioning,
        isPaused: isPaused,
        isProcessing: isProcessing,
        isFinishingTranscript: isFinishingTranscript,
        isPausing: isPausing,
        transcript: transcript,
        transcriptSegments: transcriptSegments,
        partialTranscript: partialTranscript,
        summary: summary,
        fontSize: fontSize,
        pausedDuration: pausedDuration,
      );

      if (statusMessage.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusText(statusMessage, fontSize: 14),
            const SizedBox(height: 12),
            Expanded(child: transcriptBody),
          ],
        );
      }

      return transcriptBody;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.message_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            StringKeys.homeIdlePromptLine1.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          Text(
            StringKeys.homeIdlePromptLine2.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptScrollContent({
    required bool isCaptioning,
    required bool isPaused,
    required bool isProcessing,
    required bool isFinishingTranscript,
    required bool isPausing,
    required String transcript,
    required List<TranscriptSegmentEntry> transcriptSegments,
    required String partialTranscript,
    required String summary,
    required double fontSize,
    required String pausedDuration,
  }) {
    if (isPaused) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _PausedHeader(
              status: StringKeys.homeStatusPaused.tr,
              duration: pausedDuration,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SpeakerBadge(),
                  const SizedBox(height: 12),
                  _TranscriptSegmentsView(
                    transcript: transcript,
                    transcriptSegments: transcriptSegments,
                    fontSize: fontSize,
                    showProcessingTail: isPausing || isProcessing,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SpeakerBadge(),
          const SizedBox(height: 12),
          if (isProcessing && summary.isEmpty)
            Text(
              StringKeys.homeProcessing.tr,
              style: TextStyle(
                fontSize: fontSize,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            )
          else
            _TranscriptSegmentsView(
              transcript: transcript,
              transcriptSegments: transcriptSegments,
              partialTranscript: partialTranscript,
              fontSize: fontSize,
              showProcessingTail: isFinishingTranscript,
              showListeningWhenEmpty: isCaptioning && !isPaused,
            ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              StringKeys.homeSummaryLabel.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.statusIdle,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              summary,
              style: TextStyle(
                fontSize: fontSize - 4,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TranscriptSegmentsView extends StatelessWidget {
  const _TranscriptSegmentsView({
    required this.transcript,
    required this.transcriptSegments,
    required this.fontSize,
    this.partialTranscript = '',
    this.showProcessingTail = false,
    this.showListeningWhenEmpty = false,
  });

  final String transcript;
  final List<TranscriptSegmentEntry> transcriptSegments;
  final double fontSize;
  final String partialTranscript;
  final bool showProcessingTail;
  final bool showListeningWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final processingStyle = TextStyle(
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final listeningStyle = processingStyle;

    if (transcriptSegments.isEmpty &&
        partialTranscript.isEmpty &&
        !showProcessingTail) {
      if (transcript.trim().isNotEmpty) {
        return _SegmentTranscriptText(
          segments: [
            TranscriptSegmentEntry(
              text: transcript.trim(),
              recordedAt: DateTime.now(),
            ),
          ],
          fontSize: fontSize,
          showTime: false,
        );
      }

      if (showListeningWhenEmpty) {
        return Text(StringKeys.homeListening.tr, style: listeningStyle);
      }

      return const SizedBox.shrink();
    }

    final hasLeadingContent = transcriptSegments.isNotEmpty;
    final hasPartial = partialTranscript.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (transcriptSegments.isNotEmpty)
          _SegmentTranscriptText(
            segments: transcriptSegments,
            fontSize: fontSize,
          ),
        if (hasPartial) ...[
          if (hasLeadingContent) const SizedBox(height: 12),
          Text(partialTranscript, style: processingStyle),
        ],
        if (showProcessingTail) ...[
          if (hasLeadingContent || hasPartial) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
          ],
          Text(StringKeys.homeProcessing.tr, style: processingStyle),
        ] else if (!hasLeadingContent && !hasPartial && showListeningWhenEmpty)
          Text(StringKeys.homeListening.tr, style: listeningStyle),
      ],
    );
  }
}

class _SegmentTranscriptText extends StatelessWidget {
  const _SegmentTranscriptText({
    required this.segments,
    required this.fontSize,
    this.showTime = true,
  });

  final List<TranscriptSegmentEntry> segments;
  final double fontSize;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      color: AppColors.textPrimary,
      height: 1.4,
    );
    final timeStyle = TextStyle(
      fontSize: fontSize - 6,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      height: 1.2,
    );

    if (segments.length == 1 && !showTime) {
      return Text(segments.first.text, style: textStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const Spacer(),
              Text(
                formatSegmentClockTime(segments[i].recordedAt),
                style: timeStyle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(segments[i].text, style: textStyle),
        ],
      ],
    );
  }
}

class _SpeakerBadge extends StatelessWidget {
  const _SpeakerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        StringKeys.homeSpeakerLabel.tr,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.background,
        ),
      ),
    );
  }
}

class _PausedHeader extends StatelessWidget {
  const _PausedHeader({
    required this.status,
    required this.duration,
  });

  final String status;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF9ED2D0),
        ),
      ),
      child: Text(
        '$status  •  $duration',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF2C6B73),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
