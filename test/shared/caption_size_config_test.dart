import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/shared/caption_size_config.dart';

void main() {
  test('CaptionSizeConfig bounds stay consistent', () {
    expect(CaptionSizeConfig.min, 12.0);
    expect(CaptionSizeConfig.max, 20.0);
    expect(CaptionSizeConfig.defaultSize, 16.0);
    expect(CaptionSizeConfig.step, 2.0);
    expect(CaptionSizeConfig.min, lessThan(CaptionSizeConfig.defaultSize));
    expect(CaptionSizeConfig.defaultSize, lessThan(CaptionSizeConfig.max));
    expect(
      (CaptionSizeConfig.max - CaptionSizeConfig.min) % CaptionSizeConfig.step,
      0,
    );
  });
}
