import 'package:flutter/material.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class SummarySection extends StatelessWidget {
  final String title;
  final String source;
  final String content;

  const SummarySection({
    super.key,
    this.title = 'Summary',
    this.source = 'on-device',
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.summaryBackgroundStart,
            AppColors.summaryBackgroundEnd,
          ],
        ),
        border: Border.all(
          color: AppColors.summaryBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          Text(
            content,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.auto_awesome,
          size: 22,
          color: AppColors.summaryPurple,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.summaryPurple,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '•',
          style: TextStyle(
            color: AppColors.textDivider,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          source,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        _buildPrivateBadge(),
      ],
    );
  }

  Widget _buildPrivateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
          color: AppColors.privateBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.historyBadgeMeeting,
          )),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          SizedBox(width: 4),
          Text(
            'Private',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
