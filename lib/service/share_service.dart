import 'dart:ui';

import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService({SharePlus? sharePlus}) : _sharePlus = sharePlus;

  final SharePlus? _sharePlus;

  Future<ShareResultStatus> shareFile({
    required String title,
    required String filePath,
    Rect? sharePositionOrigin,
  }) async {
    final result = await (_sharePlus ?? SharePlus.instance).share(
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
