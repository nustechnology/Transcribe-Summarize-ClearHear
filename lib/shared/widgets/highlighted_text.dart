import 'package:flutter/material.dart';
import 'package:transcribe_summarize_clearhear/style/app_colors.dart';

class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.keyword,
    this.enabled = true,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String text;
  final String keyword;
  final bool enabled;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    if (!enabled || keyword.isEmpty || text.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    final List<TextSpan> spans = [];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + keyword.length),
          style: const TextStyle(
            backgroundColor: AppColors.primary,
            color: Colors.white,
          ),
        ),
      );

      start = index + keyword.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: softWrap ?? true,
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
