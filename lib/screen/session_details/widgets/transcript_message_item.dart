import 'package:flutter/material.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class TranscriptMessageItem extends StatelessWidget {
  const TranscriptMessageItem({
    super.key,
    required this.time,
    required this.message,
  });

  final String time;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: IntrinsicHeight(
        child: Row(
          children: [
            /// Time section
            Container(
              height: double.infinity,
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                time,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(width: 16),

            /// Message
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 24.0, top: 4.0),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.textDivider,
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
