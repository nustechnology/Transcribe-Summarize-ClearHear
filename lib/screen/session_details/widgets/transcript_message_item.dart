import 'package:flutter/material.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class TranscriptMessageItem extends StatelessWidget {
  const TranscriptMessageItem({
    super.key,
    required this.time,
    required this.message,
    this.speakerLabel,
  });

  final String time;
  final String message;
  final String? speakerLabel;

  @override
  Widget build(BuildContext context) {
    final label = speakerLabel?.trim();
    final hasSpeaker = label != null && label.isNotEmpty;
    final speakerColor = AppColors.colorForSpeaker(label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                time,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 10, top: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.textDivider,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasSpeaker) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _SpeakerAvatar(
                            label: label,
                            color: speakerColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: speakerColor,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Padding(
                      padding: EdgeInsets.only(left: hasSpeaker ? 36 : 0),
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerAvatar extends StatelessWidget {
  const _SpeakerAvatar({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        speakerInitials(label),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// Initials for avatar: `Speaker 1` → `S1`, `Jane Smith` → `JS`.
@visibleForTesting
String speakerInitials(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return '?';

  final speakerMatch =
      RegExp(r'^Speaker\s+(\d+)$', caseSensitive: false).firstMatch(trimmed);
  if (speakerMatch != null) {
    return 'S${speakerMatch.group(1)}';
  }

  final parts =
      trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    if (word.length >= 2) {
      return word.substring(0, 2).toUpperCase();
    }
    return word.toUpperCase();
  }

  return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
}
