import 'dart:ui';

import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<ShareResultStatus> shareFile({
    required String title,
    required String filePath,
    Rect? sharePositionOrigin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            filePath,
            mimeType: 'text/plain',
          ),
        ],
        subject: title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    return result.status;
  }
}
