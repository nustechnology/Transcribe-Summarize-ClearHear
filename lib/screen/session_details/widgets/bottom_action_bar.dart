import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/lang/string_keys.dart';
import 'package:transcribe_summarize_clearhear/style/theme.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.onShare,
    required this.onDelete,
    this.isSharing = false,
    this.isDeleting = false,
  });

  final ValueChanged<Rect?> onShare;
  final VoidCallback onDelete;
  final bool isSharing;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  isSharing ? null : () => onShare(_shareOrigin(context)),
              icon: isSharing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.file_upload_outlined,
                      size: 24.0,
                    ),
              label: Text(
                StringKeys.historyDetailShare.tr,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16.0),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: isDeleting ? null : onDelete,
              icon: isDeleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.stopRed,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              color: AppColors.stopRed,
              iconSize: 24,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }

    return box.localToGlobal(Offset.zero) & box.size;
  }
}
