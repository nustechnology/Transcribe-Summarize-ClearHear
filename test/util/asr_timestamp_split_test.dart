import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/util/asr_timestamp_split.dart';
import 'package:transcribe_summarize_clearhear/util/pcm_audio_util.dart';

void main() {
  group('joinAsrTokens', () {
    test('joins sentencepiece-style tokens with word breaks', () {
      expect(
        joinAsrTokens(['▁hello', '▁world']),
        'hello world',
      );
      expect(
        joinAsrTokens(['▁speak', 'er', '▁one']),
        'speaker one',
      );
    });
  });

  group('splitAsrTextAtCutSeconds', () {
    test('splits on token timestamps', () {
      final split = splitAsrTextAtCutSeconds(
        fullText: 'Hello world today',
        tokens: ['▁Hello', '▁world', '▁today'],
        timestamps: [0.2, 0.8, 1.5],
        cutSeconds: 1.0,
      );
      expect(split.prefix, 'Hello world');
      expect(split.suffix, 'Today');
    });

    test('falls back to proportional word split without timestamps', () {
      final split = splitAsrTextAtCutSeconds(
        fullText: 'Hello world today friends',
        tokens: const [],
        timestamps: const [],
        cutSeconds: 1.0,
        utteranceDurationSeconds: 2.0,
      );
      expect(split.prefix, isNotEmpty);
      expect(split.suffix, isNotEmpty);
      expect(
        '${split.prefix} ${split.suffix}'.toLowerCase(),
        'hello world today friends',
      );
    });

    test('all text is prefix when cut is at/after end', () {
      final split = splitAsrTextAtCutSeconds(
        fullText: 'Hello world',
        tokens: const [],
        timestamps: const [],
        cutSeconds: 5.0,
        utteranceDurationSeconds: 2.0,
      );
      expect(split.prefix, 'Hello world');
      expect(split.suffix, isEmpty);
    });
  });

  group('hasSpeechEnergy', () {
    test('rejects near-silent buffers', () {
      final quiet = Float32List(1600); // 0.1s of zeros
      expect(hasSpeechEnergy(quiet, minRms: 0.015), isFalse);
    });

    test('accepts loud speech-like buffers', () {
      final loud = Float32List.fromList(
        List<double>.generate(1600, (i) => i.isEven ? 0.2 : -0.2),
      );
      expect(hasSpeechEnergy(loud, minRms: 0.015), isTrue);
    });
  });
}
