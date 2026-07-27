import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:transcribe_summarize_clearhear/service/share_service.dart';

class _FakeSharePlatform implements SharePlatform {
  ShareParams? lastParams;
  ShareResultStatus status = ShareResultStatus.success;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return ShareResult(status.name, status);
  }
}

void main() {
  test('shareFile forwards params and returns platform status', () async {
    final platform = _FakeSharePlatform()
      ..status = ShareResultStatus.unavailable;
    final service = ShareService(sharePlus: SharePlus.custom(platform));
    const origin = Rect.fromLTWH(1, 2, 3, 4);

    final status = await service.shareFile(
      title: 'Meeting notes',
      filePath: '/tmp/session.txt',
      sharePositionOrigin: origin,
    );

    expect(status, ShareResultStatus.unavailable);
    expect(platform.lastParams?.subject, 'Meeting notes');
    expect(platform.lastParams?.sharePositionOrigin, origin);
    expect(platform.lastParams?.files, hasLength(1));
    expect(platform.lastParams?.files?.single.path, '/tmp/session.txt');
    expect(platform.lastParams?.files?.single.mimeType, 'text/plain');
  });
}
