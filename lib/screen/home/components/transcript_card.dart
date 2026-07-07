import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../lang/string_keys.dart';
import '../../../model/transcript_segment_entry.dart';
import '../../../style/theme.dart';
import '../../../util/asr_text_util.dart';
import '../controllers/home_controller.dart';
import 'name_avatar.dart';

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
  Worker? _summaryWorker;

  @override
  void initState() {
    super.initState();
    _transcriptWorker =
        ever(widget.controller.transcriptSegments, (_) => _scrollToBottom());
    _summaryWorker = ever(widget.controller.summary, (_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _transcriptWorker?.dispose();
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
      final summary = controller.summary.value.trim();
      final statusMessage = controller.statusMessage.value;
      final fontSize = controller.transcriptFontSize.value;
      final transcriptSpeakers = controller.transcriptSpeakers.value;
      final isLoadingTranscriptSpeakers = controller.isLoadingTranscript.value;
      final sessionDuration = controller.sessionDuration.value;
      final hasFrozenContent = controller.finalizedParagraphs.isNotEmpty;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: (isCaptioning || hasFrozenContent)
              ? AppColors.surface
              : AppColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: (isCaptioning || hasFrozenContent)
              ? Border.all(color: AppColors.border.withValues(alpha: 0.5))
              : null,
          boxShadow: (isCaptioning || hasFrozenContent)
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
          transcript: transcript,
          transcriptSegments: transcriptSegments,
          summary: summary,
          statusMessage: statusMessage,
          fontSize: fontSize,
          transcriptSpeakers: transcriptSpeakers,
          isLoadingTranscriptSpeakers: isLoadingTranscriptSpeakers,
          sessionDuration: sessionDuration,
          hasFrozenContent: hasFrozenContent,
        ),
      );
    });
  }

  Widget _buildContent({
    required bool isCaptioning,
    required bool isPaused,
    required bool isProcessing,
    required bool isFinishingTranscript,
    required String transcript,
    required List<TranscriptSegmentEntry> transcriptSegments,
    required String summary,
    required String statusMessage,
    required double fontSize,
    required List<Map<String, dynamic>> transcriptSpeakers,
    required bool isLoadingTranscriptSpeakers,
    required String sessionDuration,
    required bool hasFrozenContent,
  }) {
    if (statusMessage.isNotEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Text(
          StringKeys.t(statusMessage),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFFE53935),
            height: 1.4,
          ),
        ),
      );
    }

    // Paused state: show frozen speaker list with duration header.
    if (isCaptioning && isPaused) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Center(
              child: _PausedHeader(duration: sessionDuration),
            ),
          ),
          Expanded(
            child: isLoadingTranscriptSpeakers
                ? const Center(child: CircularProgressIndicator())
                : transcriptSpeakers.isEmpty
                    ? const Center(
                        child: Text(
                          'No transcript yet.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: transcriptSpeakers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 24),
                        itemBuilder: (context, index) {
                          final item = transcriptSpeakers[index];
                          final speaker = item['speaker'] as String;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NameAvatar(name: speaker),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      speaker,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: NameAvatar.colorForName(speaker),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item['message'] as String,
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        color: AppColors.textPrimary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Captions are saved locally on your device.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      );
    }

    // Live captioning or frozen stopped state.
    if (isCaptioning || hasFrozenContent) {
      return _LiveCaptionArea(
        controller: widget.controller,
        fontSize: fontSize,
        isProcessing: isProcessing,
        summary: summary,
        isFrozen: !isCaptioning,
      );
    }

    // Post-stop state: show finalized transcript segments.
    if (isFinishingTranscript ||
        transcript.trim().isNotEmpty ||
        transcriptSegments.isNotEmpty) {
      return SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              StringKeys.homeSpeakerLabel.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.statusIdle,
                letterSpacing: 0.8,
              ),
            ),
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
                fontSize: fontSize,
                showProcessingTail: isFinishingTranscript,
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

    // Idle state.
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
}

class _TranscriptSegmentsView extends StatelessWidget {
  const _TranscriptSegmentsView({
    required this.transcript,
    required this.transcriptSegments,
    required this.fontSize,
    this.showProcessingTail = false,
  });

  final String transcript;
  final List<TranscriptSegmentEntry> transcriptSegments;
  final double fontSize;
  final bool showProcessingTail;

  @override
  Widget build(BuildContext context) {
    final processingStyle = TextStyle(
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      color: AppColors.textSecondary,
      height: 1.4,
    );
    if (transcriptSegments.isEmpty && !showProcessingTail) {
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

      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (transcriptSegments.isNotEmpty)
          _SegmentTranscriptText(
            segments: transcriptSegments,
            fontSize: fontSize,
          ),
        if (showProcessingTail) ...[
          if (transcriptSegments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
          ],
          Text(StringKeys.homeProcessing.tr, style: processingStyle),
        ],
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

/// Live caption area with auto-scroll and partial/final text rendering.
class _LiveCaptionArea extends StatefulWidget {
  const _LiveCaptionArea({
    required this.controller,
    required this.fontSize,
    required this.isProcessing,
    required this.summary,
    required this.isFrozen,
  });

  final HomeController controller;
  final double fontSize;
  final bool isProcessing;
  final String summary;
  final bool isFrozen;

  @override
  State<_LiveCaptionArea> createState() => _LiveCaptionAreaState();
}

class _LiveCaptionAreaState extends State<_LiveCaptionArea> {
  final ScrollController _scrollController = ScrollController();
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 8;
    if (atBottom) {
      _userScrolledUp = false;
    } else {
      _userScrolledUp = true;
    }
  }

  void _scrollToBottom() {
    if (_userScrolledUp || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent) {
      _scrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          StringKeys.homeSpeakerLabel.tr,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.statusIdle,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildScrollableContent(),
        ),
        if (widget.summary.isNotEmpty) ...[
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
            widget.summary,
            style: TextStyle(
              fontSize: widget.fontSize - 4,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScrollableContent() {
    return Obx(() {
      final paragraphs = widget.controller.finalizedParagraphs.toList();
      // Trigger scroll after frame renders.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Finalized paragraphs (rendered infrequently).
          if (paragraphs.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildParagraphItem(paragraphs, index),
                childCount: paragraphs.length,
              ),
            ),
          // Partial text (updates frequently — separate Obx).
          SliverToBoxAdapter(
            child: widget.isFrozen
                ? const SizedBox.shrink()
                : Obx(() {
                    final partial =
                        widget.controller.partialText.value.trim();
                    // Scroll to bottom whenever partial changes.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                    if (partial.isEmpty) {
                      // Show listening indicator so user knows we're active,
                      // whether paragraphs are empty or not.
                      return _listeningIndicator();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        partial,
                        style: TextStyle(
                          fontSize: widget.fontSize,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                      ),
                    );
                  }),
          ),
          // Bottom padding so last line is not clipped.
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      );
    });
  }

  Widget _buildParagraphItem(List<String> paragraphs, int index) {
    if (paragraphs.isEmpty) {
      return _listeningIndicator();
    }
    final text = paragraphs[index];
    if (text.isEmpty) {
      // Paragraph break separator.
      return const SizedBox(height: 16);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: widget.fontSize,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _listeningIndicator() {
    if (widget.isFrozen) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        StringKeys.homeListening.tr,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontStyle: FontStyle.italic,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PausedHeader extends StatelessWidget {
  const _PausedHeader({required this.duration});

  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF9ED2D0)),
      ),
      child: Text(
        'Paused - $duration',
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF2C6B73),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
