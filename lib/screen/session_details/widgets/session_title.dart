import 'package:flutter/material.dart';
import 'package:transcribe_summarize_clearhear/shared/widgets/inline_editable_title.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class SessionTitle extends StatelessWidget {
  const SessionTitle({
    super.key,
    required this.title,
    required this.date,
    required this.duration,
    required this.onTitleSave,
    required this.onTitleEditingChanged,
  });

  final String title;
  final String date;
  final String duration;
  final Future<void> Function(String title) onTitleSave;
  final ValueChanged<bool> onTitleEditingChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.historyBadgeMeeting.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.people_alt,
            color: AppColors.accent,
            size: 24,
          ),
        ),

        const SizedBox(width: 16),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InlineEditableTitle(
                initialTitle: title,
                onSave: onTitleSave,
                onEditingChanged: onTitleEditingChanged,
                showTrailingIcon: false,
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                inputStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),
              Row(
                children: [
                  _MetaText(text: date),
                  const _Dot(),
                  _MetaText(text: duration),
                  const _Dot(),
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 16,
                    color: AppColors.gray,
                  ),
                  const SizedBox(width: 4),
                  const _MetaText(text: "offline"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  final String text;

  const _MetaText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.gray,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        "•",
        style: TextStyle(
          color: AppColors.gray,
          fontSize: 14,
        ),
      ),
    );
  }
}
