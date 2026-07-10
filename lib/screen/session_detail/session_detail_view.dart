import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/route/app_route.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/app_loading.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';
import 'package:transcribe_summarize_clearhear/util/datetime/datetime_utils.dart';

import 'controllers/session_detail_controller.dart';
import 'session_detail_dependencies.dart';

class SessionDetailView extends StatefulWidget {
  const SessionDetailView({super.key});

  @override
  State<SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<SessionDetailView> {
  SessionDetailController? _controller;
  int? _sessionId;
  bool _triedDeferredInit = false;

  @override
  void initState() {
    super.initState();
    _tryInitializeController();
  }

  int? _resolveSessionId() {
    final currentParameters =
        Get.rootDelegate.currentConfiguration?.currentPage?.parameters;
    final fromParameters = int.tryParse(
      currentParameters?['id'] ?? Get.parameters['id'] ?? '',
    );
    if (fromParameters != null) return fromParameters;

    final fromArguments = int.tryParse('${Get.arguments ?? ''}');
    if (fromArguments != null) return fromArguments;

    return null;
  }

  void _tryInitializeController() {
    ensureSessionDetailDependencies();

    final sessionId = _resolveSessionId();
    if (sessionId == null) {
      if (!_triedDeferredInit) {
        _triedDeferredInit = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(_tryInitializeController);
          }
        });
      }
      return;
    }
    if (_controller != null && _sessionId == sessionId) {
      return;
    }

    if (Get.isRegistered<SessionDetailController>()) {
      final existing = Get.find<SessionDetailController>();
      if (existing.sessionId == sessionId) {
        _controller = existing;
        _sessionId = sessionId;
        return;
      }
      Get.delete<SessionDetailController>(force: true);
    }

    final controller = SessionDetailController(
      sessionId: sessionId,
      sessionRepository: Get.find<SessionRepository>(),
      segmentRepository: Get.find<SegmentRepository>(),
      summaryService: Get.find<SessionSummaryService>(),
    );
    Get.put<SessionDetailController>(controller);
    _controller = controller;
    _sessionId = sessionId;
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null &&
        Get.isRegistered<SessionDetailController>() &&
        identical(Get.find<SessionDetailController>(), controller)) {
      Get.delete<SessionDetailController>(force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      _tryInitializeController();
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(child: AppLoading()),
        ),
      );
    }

    return Obx(() {
      final session = controller.session.value;
      final summary = session?.summary?.trim() ?? '';
      final transcript = controller.transcript.value.trim();

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
          title: const Text('Session Detail'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await Get.rootDelegate.offNamed(AppRoutes.history);
            },
          ),
        ),
        body: SafeArea(
          top: false,
          child: controller.isLoading.value && session == null
              ? const Center(child: AppLoading())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryPanel(
                        isProcessing: controller.isShowingLoading,
                        isFailed: controller.isFailed,
                        failureMessage: controller.failureMessage,
                        isRetrying: controller.isRetrying.value,
                        summary: summary,
                        onRetry: controller.retrySummary,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        session?.title ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session == null
                            ? ''
                            : DateTimeUtils.formatSmartTimestamp(
                                DateTime.fromMillisecondsSinceEpoch(
                                  session.startedAt * 1000,
                                ),
                                isFullDateFormat: true,
                              ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TRANSCRIPT',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: transcript.isEmpty
                            ? const Text(
                                'No transcript available.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  height: 1.5,
                                ),
                              )
                            : SelectableText(
                                transcript,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    });
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.isProcessing,
    required this.isFailed,
    required this.failureMessage,
    required this.isRetrying,
    required this.summary,
    required this.onRetry,
  });

  final bool isProcessing;
  final bool isFailed;
  final String failureMessage;
  final bool isRetrying;
  final String summary;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'SUMMARY',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          if (summary.isNotEmpty) ...[
            SelectableText(
              summary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.5,
                fontSize: 15,
              ),
            ),
          ] else if (isFailed) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    failureMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: isRetrying ? null : onRetry,
                  icon: isRetrying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(isRetrying ? 'Retrying...' : 'Retry'),
                ),
              ],
            ),
          ] else if (isProcessing) ...[
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI is summarizing your session...',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (summary.isEmpty) ...[
            const Text(
              'No summary available yet.',
              style: TextStyle(
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
