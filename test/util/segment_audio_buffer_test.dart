import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/service/speaker_diarization_service.dart';
import 'package:transcribe_summarize_clearhear/util/segment_audio_buffer.dart';

void main() {
  group('concatFloat32Chunks', () {
    test('joins chunks in order', () {
      final result = concatFloat32Chunks([
        Float32List.fromList([1, 2]),
        Float32List.fromList([3]),
        Float32List.fromList([4, 5]),
      ]);
      expect(result, Float32List.fromList([1, 2, 3, 4, 5]));
    });

    test('returns empty for no chunks', () {
      expect(concatFloat32Chunks(const []), isEmpty);
    });
  });

  group('takeLastSamples', () {
    test('returns trailing window across chunk boundaries', () {
      final chunks = [
        Float32List.fromList([1, 2, 3]),
        Float32List.fromList([4, 5, 6, 7]),
      ];
      expect(
        takeLastSamples(chunks, 4),
        Float32List.fromList([4, 5, 6, 7]),
      );
      expect(
        takeLastSamples(chunks, 5),
        Float32List.fromList([3, 4, 5, 6, 7]),
      );
    });

    test('returns all samples when window is larger than buffer', () {
      final chunks = [Float32List.fromList([1, 2, 3])];
      expect(
        takeLastSamples(chunks, 10),
        Float32List.fromList([1, 2, 3]),
      );
    });
  });

  group('splitTrailingWindow', () {
    test('splits prefix and tail', () {
      final chunks = [
        Float32List.fromList([1, 2, 3, 4]),
        Float32List.fromList([5, 6]),
      ];
      final split = splitTrailingWindow(chunks, 3);
      expect(split.prefix, Float32List.fromList([1, 2, 3]));
      expect(split.tail, Float32List.fromList([4, 5, 6]));
    });

    test('empty prefix when buffer shorter than window', () {
      final chunks = [Float32List.fromList([1, 2])];
      final split = splitTrailingWindow(chunks, 5);
      expect(split.prefix, isEmpty);
      expect(split.tail, Float32List.fromList([1, 2]));
    });
  });

  group('shouldForceCutOnSpeakerChange', () {
    test('cuts when other speaker wins with enough margin', () {
      expect(
        shouldForceCutOnSpeakerChange(
          pendingLabel: 'Speaker 1',
          probeMatchedLabel: 'Speaker 2',
          pendingSpeakerScore: 0.10,
          bestScore: 0.45,
        ),
        isTrue,
      );
    });

    test('does not cut when other speaker wins but margin is thin', () {
      expect(
        shouldForceCutOnSpeakerChange(
          pendingLabel: 'Speaker 1',
          probeMatchedLabel: 'Speaker 2',
          pendingSpeakerScore: 0.30,
          bestScore: 0.35,
        ),
        isFalse,
      );
    });

    test('does not cut when probe matches the pending speaker', () {
      expect(
        shouldForceCutOnSpeakerChange(
          pendingLabel: 'Speaker 1',
          probeMatchedLabel: 'Speaker 1',
          pendingSpeakerScore: 0.55,
          bestScore: 0.55,
        ),
        isFalse,
      );
    });

    test('cuts on unknown new voice only when pending score is impostor-level',
        () {
      expect(
        shouldForceCutOnSpeakerChange(
          pendingLabel: 'Speaker 1',
          probeIsUnknownNewVoice: true,
          pendingSpeakerScore: 0.10,
        ),
        isTrue,
      );
      expect(
        shouldForceCutOnSpeakerChange(
          pendingLabel: 'Speaker 1',
          probeIsUnknownNewVoice: true,
          pendingSpeakerScore: 0.20,
        ),
        isFalse,
      );
    });

    test('does not cut on inconclusive probe', () {
      expect(
        shouldForceCutOnSpeakerChange(pendingLabel: 'Speaker 1'),
        isFalse,
      );
    });
  });

  group('requiredSpeakerChangeConfirmations', () {
    test('strong cross-speaker margin cuts on first probe', () {
      expect(
        requiredSpeakerChangeConfirmations(
          probeMatchedLabel: 'Speaker 2',
          pendingSpeakerScore: 0.08,
          bestScore: 0.40,
        ),
        1,
      );
    });

    test('unknown / weak evidence needs default confirmations', () {
      expect(
        requiredSpeakerChangeConfirmations(
          pendingSpeakerScore: 0.10,
          bestScore: 0.12,
        ),
        2,
      );
    });
  });

  group('SpeakerDiarizationService probe matching', () {
    late SpeakerDiarizationService service;

    setUp(() {
      service = SpeakerDiarizationService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('identifyFromEmbedding does not mutate stored samples', () {
      service.debugRegisterSpeaker(
        'Speaker 1',
        Float32List.fromList([1, 0, 0, 0]),
      );
      service.debugRegisterSpeaker(
        'Speaker 2',
        Float32List.fromList([0, 1, 0, 0]),
      );
      expect(service.knownSpeakerCount, 2);
      expect(service.debugSampleCount('Speaker 1'), 1);
      expect(service.debugSampleCount('Speaker 2'), 1);

      final nearSpeaker2 = Float32List.fromList([0.05, 0.95, 0, 0]);
      final probe = service.debugIdentifyFromEmbedding(
        nearSpeaker2,
        relativeToLabel: 'Speaker 1',
      );
      expect(probe.matchedLabel, 'Speaker 2');
      expect(probe.pendingSpeakerScore, lessThan(0.2));
      expect(probe.isUnknownNewVoice, isFalse);

      expect(service.knownSpeakerCount, 2);
      expect(service.debugSampleCount('Speaker 1'), 1);
      expect(service.debugSampleCount('Speaker 2'), 1);
    });

    test('identifyFromEmbedding reports unknown new voice below threshold', () {
      service.debugRegisterSpeaker(
        'Speaker 1',
        Float32List.fromList([1, 0, 0, 0]),
      );

      final other = Float32List.fromList([0, 1, 0, 0]);
      final probe = service.debugIdentifyFromEmbedding(
        other,
        relativeToLabel: 'Speaker 1',
      );
      expect(probe.matchedLabel, isNull);
      expect(probe.isUnknownNewVoice, isTrue);
      expect(probe.pendingSpeakerScore, closeTo(0.0, 1e-6));
      expect(service.knownSpeakerCount, 1);
      expect(service.debugSampleCount('Speaker 1'), 1);
    });
  });
}
